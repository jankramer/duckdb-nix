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
      icu = self.mkExtension { name = "icu"; };
      json = self.mkExtension { name = "json"; };
      parquet = self.mkExtension { name = "parquet"; };

      avro = self.callPackage ./extensions/avro { };
      ducklake = self.callPackage ./extensions/ducklake { };
      httpfs = self.callPackage ./extensions/httpfs { };
      postgres = self.callPackage ./extensions/postgres { };
      quack = self.callPackage ./extensions/quack { };
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
    inherit (scope) withExtensions mkExtension extensions;

    src = scope.duckdb-src;
    core = scope.duckdb-core;
  };
})
