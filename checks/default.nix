{ pkgs, duckdb }:
let
  minimal = duckdb.withExtensions (e: [
    e.core_functions
    e.json
  ]);
  withIcu = duckdb.withExtensions (e: [
    e.core_functions
    e.json
    e.icu
  ]);
  withRemote = duckdb.withExtensions (e: [
    e.core_functions
    e.json
    e.icu
    e.httpfs
    e.parquet
  ]);
  gcsFirst = duckdb.withExtensions (e: [
    e.autocomplete
    e.core_functions
    e.parquet
    e.gcs
    e.httpfs
    e.icu
    e.json
  ]);
  cliOnly = duckdb.mkDuckdb {
    extensions = [ duckdb.extensions.core_functions ];
    withJdbc = false;
  };
  engine = "${duckdb.core}/lib/libduckdb_static.a";
  variants = [
    minimal
    withIcu
    withRemote
    gcsFirst
    duckdb
  ];
  sharedEngine = builtins.all (
    package:
    package.core == duckdb.core
    && builtins.all (ext: ext.core == duckdb.core) package.selectedExtensions
  ) variants;
in
assert sharedEngine;
{
  capi =
    pkgs.runCommand "duckdb-capi-check"
      {
        nativeBuildInputs = [ pkgs.stdenv.cc ];
      }
      ''
        mkdir -p "$out"
        export HOME="$TMPDIR"
        cc -I${duckdb.src}/src/include ${./capi.c} -L${duckdb}/lib -lduckdb \
          -Wl,-rpath,${duckdb}/lib -o capi
        ./capi > "$out/result.txt"
        test ! -e ${cliOnly}/share/java
        test "$(${cliOnly}/bin/duckdb -init /dev/null -csv -noheader -c 'SELECT 42')" = 42
      '';
  composition =
    pkgs.runCommand "duckdb-composition-check"
      {
        # The fixtures bind only to loopback, including inside Darwin's sandbox.
        __darwinAllowLocalNetworking = true;
        nativeBuildInputs = [
          pkgs.jdk
          pkgs.python3
          pkgs.stdenv.cc
          pkgs.openssl
        ];
      }
      ''
        cp ${./verify.py} verify.py
        cp ${./Smoke.java} Smoke.java
        python3 verify.py ${minimal} ${withIcu} ${withRemote} ${engine} "$out"
        cp ${./remote.py} remote.py
        cp ${./RemoteSmoke.java} RemoteSmoke.java
        python3 remote.py ${minimal} ${withRemote} ${duckdb.extensions.httpfs} ${duckdb.extensions.parquet} "$out"
      '';
  gcs =
    pkgs.runCommand "duckdb-gcs-check"
      {
        __darwinAllowLocalNetworking = true;
        nativeBuildInputs = [
          pkgs.jdk
          pkgs.python3
        ];
      }
      ''
        cp ${./Smoke.java} Smoke.java
        cp ${./GcsSmoke.java} GcsSmoke.java
        cp ${./gcs.py} gcs.py
        python3 gcs.py ${gcsFirst} ${duckdb} ${engine} "$out"
      '';
}
// pkgs.lib.mapAttrs' (name: value: pkgs.lib.nameValuePair "extension-${name}" value) (
  import ./catalog.nix { inherit pkgs duckdb; }
)
