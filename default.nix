{
  lib,
  newScope,
  symlinkJoin,
}:

let
  scope = lib.makeScope newScope (self: {
    duckdb-src = self.callPackage ./duckdb-src { };
    duckdb-core = self.callPackage ./duckdb-core { };
    duckdb-java = self.callPackage ./duckdb-java { };

    mkDuckdb = self.callPackage ./lib/mkDuckdb.nix { };
    mkExtension = self.callPackage ./lib/mkExtension.nix { };

    extensions = {
      autocomplete = self.mkExtension { name = "autocomplete"; };
      core_functions = self.mkExtension { name = "core_functions"; };
      demo_capi = self.mkExtension { name = "demo_capi"; };
      icu = self.mkExtension { name = "icu"; };
      json = self.mkExtension { name = "json"; };
      parquet = self.mkExtension { name = "parquet"; };
      tpcds = self.mkExtension { name = "tpcds"; };
      tpch = self.mkExtension { name = "tpch"; };

      avro = self.callPackage ./extensions/avro { };
      aws = self.callPackage ./extensions/aws { };
      azure = self.callPackage ./extensions/azure { };
      ducklake = self.callPackage ./extensions/ducklake { };
      encodings = self.callPackage ./extensions/encodings { };
      excel = self.callPackage ./extensions/excel { };
      fts = self.callPackage ./extensions/fts { };
      httpfs = self.callPackage ./extensions/httpfs { };
      iceberg = self.callPackage ./extensions/iceberg { };
      inet = self.callPackage ./extensions/inet { };
      mysql_scanner = self.callPackage ./extensions/mysql_scanner { };
      odbc_scanner = self.callPackage ./extensions/odbc_scanner { };
      postgres_scanner = self.callPackage ./extensions/postgres { };
      quack = self.callPackage ./extensions/quack { };
      sqlite_scanner = self.callPackage ./extensions/sqlite_scanner { };
      sqlsmith = self.callPackage ./extensions/sqlsmith { };
      unity_catalog = self.callPackage ./extensions/unity_catalog { };
      vss = self.callPackage ./extensions/vss { };
    };

    defaultExtensions = builtins.attrValues self.extensions;

    default = self.mkDuckdb {
      configuredExtensions = self.defaultExtensions;
      withJdbc = true;
    };

    withExtensions =
      selectFn:
      self.mkDuckdb {
        configuredExtensions = selectFn self.extensions;
        withJdbc = true;
      };
  });
in
scope.default.overrideAttrs (previousAttrs: {
  passthru = (previousAttrs.passthru or { }) // {
    inherit (scope) withExtensions mkExtension extensions defaultExtensionNames defaultExtensions;

    src = scope.duckdb-src;
    core = scope.duckdb-core;
  };
})
