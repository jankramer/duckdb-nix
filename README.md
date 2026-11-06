# DuckDB Nix Flake

DuckDB CLI and JDBC driver with configurable extensions, packaged for
`aarch64-darwin`, `aarch64-linux`, and `x86_64-linux`.

```sh
nix run github:jankramer/duckdb-nix
nix build github:jankramer/duckdb-nix
./result/bin/duckdb
```

The default extensions are `autocomplete`, `core_functions`, `parquet`,
`httpfs`, `gcs`, `icu`, and `json`.

To use the package in another flake, add an input:

```nix
inputs.duckdb.url = "github:jankramer/duckdb-nix";
```

Select extensions with `withExtensions`:

```nix
let
  duckdb = inputs.duckdb.packages.${system}.default;
in
duckdb.withExtensions (e: [ e.core_functions e.json e.parquet e.httpfs ])
```

The `overlays.default` output also exposes the package as `pkgs.duckdb`.
Selected extensions load automatically in both CLI and JDBC. To add an extension,
change the Nix selection and rebuild; runtime `INSTALL` is unavailable. Include
extension dependencies, such as Parquet for DuckLake and Avro for Iceberg.

JDBC requires Java 11 or later and the package's Nix store dependencies at
runtime. Add one of these JARs to your classpath:

- `result/share/java/duckdb_jdbc.jar` includes the native driver.
- `result/share/java/duckdb_jdbc_nolib.jar` requires
  `-Djava.library.path=/absolute/path/to/result/lib`.

Connect using the JDBC URL `jdbc:duckdb:` for an in-memory database or
`jdbc:duckdb:/path/to/database.duckdb` for a database file.

GCS supports `gs://`, `gcs://`, and `gcss://` URLs and uses Application Default
Credentials when no explicit GCP secret is supplied. Explicit credentials take
precedence. When passing HTTPFS settings as JDBC connection properties, also set
`autoload_known_extensions=true` and `autoinstall_known_extensions=false`.

Run the checks from a checkout with `nix flake check`. They cover CLI, JDBC,
extension composition, and local HTTP/GCS fixtures without cloud credentials.
