{ pkgs, duckdb }:
let
  baseNames = [
    "core_functions"
    "json"
    "icu"
    "parquet"
    "httpfs"
  ];
  names = pkgs.lib.subtractLists (baseNames ++ [ "gcs" ]) (builtins.attrNames duckdb.extensions);
  probes = {
    autocomplete = "SELECT * FROM sql_auto_complete('SELECT ') LIMIT 1";
    demo_capi = "SELECT add_numbers_together(19, 23)";
    inet = "SELECT '127.0.0.1'::INET";
    sqlite_scanner = "ATTACH ':memory:' AS s (TYPE SQLITE); CREATE TABLE s.t AS SELECT 42 AS i; SELECT * FROM s.t";
    tpch = "CALL dbgen(sf=0); SELECT count(*) FROM lineitem";
    tpcds = "CALL dsdgen(sf=0); SELECT count(*) FROM store_sales";
    fts = "CREATE TABLE docs AS SELECT 1 AS id, 'hello world' AS text; PRAGMA create_fts_index('docs', 'id', 'text')";
    vss = "CREATE TABLE vectors (v FLOAT[3]); CREATE INDEX hnsw_idx ON vectors USING HNSW(v)";
    odbc_scanner = "SET enable_external_access=false; SELECT * FROM odbc_list_drivers()";
  };
in
pkgs.lib.genAttrs names (
  name:
  let
    selected =
      baseNames
      ++ pkgs.lib.optional (name == "iceberg") "avro"
      # Both scanners define similarly named C++ helpers; test their composition.
      ++ pkgs.lib.optional (name == "mysql_scanner") "postgres_scanner"
      ++ [ name ];
    package = duckdb.withExtensions (e: map (n: e.${n}) selected);
    expected = pkgs.lib.concatStringsSep "," (builtins.sort builtins.lessThan selected);
    sql = probes.${name} or "SELECT 42";
  in
  pkgs.runCommand "duckdb-extension-${name}-check"
    {
      nativeBuildInputs = [ pkgs.jdk ];
    }
    ''
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME" "$out"
      ${package}/bin/duckdb -init /dev/null -csv -noheader -bail :memory: -c \
        "SELECT string_agg(extension_name, ',' ORDER BY extension_name) FROM duckdb_extensions() WHERE loaded AND extension_name <> 'shell'" > "$out/loaded.txt"
      actual="$(tr -d '\"' < "$out/loaded.txt")"
      if [ "$actual" != ${pkgs.lib.escapeShellArg expected} ]; then
        echo "Unexpected extension set: $actual" >&2
        exit 1
      fi
      ${package}/bin/duckdb -init /dev/null -bail :memory: -c ${pkgs.lib.escapeShellArg sql} > "$out/cli.txt"
      cp ${./Smoke.java} Smoke.java
      cp ${./CatalogSmoke.java} CatalogSmoke.java
      javac --release 11 Smoke.java CatalogSmoke.java
      java -Djava.io.tmpdir="$TMPDIR" -Djava.library.path="$HOME" \
        -cp .:${package}/share/java/duckdb_jdbc.jar CatalogSmoke ${
          pkgs.lib.escapeShellArgs [
            expected
            sql
          ]
        } > "$out/jdbc-packed.txt"
      java -Djava.library.path=${package}/lib \
        -cp .:${package}/share/java/duckdb_jdbc_nolib.jar CatalogSmoke ${
          pkgs.lib.escapeShellArgs [
            expected
            sql
          ]
        } > "$out/jdbc-external.txt"
    ''
)
