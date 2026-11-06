# Match the extension revisions and compatibility patches shipped with DuckDB 2.0.
{
  applyPatches,
  fetchFromGitHub,
  duckdb-src,
}:
let
  databaseConnector = fetchFromGitHub {
    owner = "duckdb";
    repo = "database-connector";
    rev = "c305670b5729cc6dbda8d395eeb63b4d1487c064";
    hash = "sha256-ARgCKrySFbAuSUp3A2PGY9/538qGha9zzG43hlMBgFo=";
  };
in
{
  avro = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-avro";
    rev = "758fb6063cbb6da49b2e1c16c4044cfcafefc52f";
    hash = "sha256-8e+nuPU7JPt0sHgYI0OykzJPsS/dMj0y/ny36qKJQD0=";
  };
  aws = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-aws";
    rev = "16ae9c135300f750478d648c2496f2952a6f2827";
    hash = "sha256-YjOMPH2jdQ8s8VYXM+lhhvx0Lbp4KT/YVc5Yg67w3mI=";
  };
  azure = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-azure";
    rev = "906e92458c33309e5d9413e14a85aad7b4d2275f";
    hash = "sha256-UJBf8lsJqaRpIwqR9+tGpVx3h5OjLiPAbgZl6L5Hemw=";
  };
  ducklake = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "ducklake";
      rev = "417a9117f590e8141742ac0579d02f6a90162e37";
      hash = "sha256-CfGNeFJlTjLS5/2GEg4EU8Ph9I8mLPax96wCNOIrgZk=";
    };
    patches = [
      (duckdb-src + "/.github/patches/extensions/ducklake/0018-timestamptz-retype-test-load-icu.patch")
      (duckdb-src + "/.github/patches/extensions/ducklake/0019-skip-sorted-flush-parallel-on-musl.patch")
      (
        duckdb-src
        + "/.github/patches/extensions/ducklake/0021-compaction-twice-glob-windows-separators.patch"
      )
      (duckdb-src + "/.github/patches/extensions/ducklake/0022-add-files-tests-duckdb-data-path.patch")
      (
        duckdb-src
        + "/.github/patches/extensions/ducklake/0022-remote-path-aliases-legacy-url-parameters.patch"
      )
      (
        duckdb-src
        + "/.github/patches/extensions/ducklake/0023-skip-murmur3-small-numeric-types-on-windows.patch"
      )
    ];
  };
  encodings = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-encodings";
    rev = "2d1447a890302d9dff23ac7c8119ddce53ee65ff";
    hash = "sha256-EF2lbkvQwXjl79VdIlzvsVsxq3VvujGHZO1ELmiA7P4=";
  };
  excel = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-excel";
    rev = "81bb84b115b97cc4edec4827714cac80da0127e1";
    hash = "sha256-6Z5MLv9aT09KMSwvgsTWsWpst1nmBZ90xEHX/r98ZEk=";
  };
  fts = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-fts";
      rev = "2266e67d01c737cb65114e77c7c672e58869a635";
      hash = "sha256-Y8MPRvD5XFsLpPEsVzALq3jQk9vqEidGBcvPDHdjkMc=";
    };
    patches = [
      (duckdb-src + "/.github/patches/extensions/fts/0001-get-default-schema-optional.patch")
      (duckdb-src + "/.github/patches/extensions/fts/0002-fts-indexing-includes.patch")
      (duckdb-src + "/.github/patches/extensions/fts/0003-pragma-function-signature-options.patch")
    ];
  };
  iceberg = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-iceberg";
    rev = "4c0c0874c48ec82a3e29910554891d04bcc0e988";
    hash = "sha256-zwhf6ePplnWagroxJ7hojgJrllRSRX66/9wH+qi3Fzw=";
  };
  inet = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-inet";
      rev = "fe7f60bb60245197680fb07ecd1629a1dc3d91c8";
      hash = "sha256-8YeYuowhFz4XctNiAU7SG+QjnuQ416erAPjKpexk7Rw=";
    };
    patches = [
      (duckdb-src + "/.github/patches/extensions/inet/0001-applied-patch-fix-patch.patch")
      (duckdb-src + "/.github/patches/extensions/inet/0002-wrap-bind-input.patch")
      (duckdb-src + "/.github/patches/extensions/inet/0003-fix-deprecated-to-unified-format.patch")
      (
        duckdb-src
        + "/.github/patches/extensions/inet/0004-bound-expression-more-private-member-accessors.patch"
      )
      (duckdb-src + "/.github/patches/extensions/inet/0005-identifier-changes.patch")
      (duckdb-src + "/.github/patches/extensions/inet/0006-ipaddress-cast-parameters-include.patch")
      (duckdb-src + "/.github/patches/extensions/inet/0007-mark-inet-arithmetic-fallible.patch")
      (duckdb-src + "/.github/patches/extensions/inet/0008-immutable-logical-type.patch")
    ];
  };
  mysql_scanner = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-mysql";
      rev = "f7fc0d42716534aa5ad48626d21ced9807b33967";
      hash = "sha256-d3Ly/Sj7xRX1bL9zKLgcRyOYhdI0vXuTVYhdDuv88co=";
    };
    postPatch = ''
      cp -R ${databaseConnector}/. database-connector/
    '';
  };
  odbc_scanner = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "odbc-scanner";
      rev = "a33698df40f95cc3eb339703dcb085497eabfca3";
      hash = "sha256-H3seSmjDKK5R+xYyEjOe1zGpM7kch8I0qqD/5KzUWQg=";
    };
    patches = [
      (duckdb-src + "/.github/patches/extensions/odbc_scanner/0001-check-external-access.patch")
    ];
  };
  postgres_scanner = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-postgres";
      rev = "c0f5a3c0c4b68b02afbf669d36d7f0e503985c88";
      hash = "sha256-97aAF2O4mZLPSmIko8jdV2orR/2M8i13SU1a1yXV8sA=";
    };
    postPatch = ''
      cp -R ${databaseConnector}/. database-connector/
    '';
  };
  quack = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-quack";
    rev = "f96420ed46aee9c42064bdb99ddfd1230d6c0086";
    hash = "sha256-S3/yaeTiJoA3efiMPksLVGlfKm3JH7I3tzuub9v3IQg=";
  };
  sqlite_scanner = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-sqlite";
      rev = "e223dc01493414cef6d5960744f1e048d59fc592";
      hash = "sha256-xVrOkXXs4ahXPgTkshgwZyg1D0mPRGYh+bm5eEUXwpg=";
    };
    postPatch = ''
      cp -R ${databaseConnector}/. database-connector/
    '';
  };
  sqlsmith = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-sqlsmith";
    rev = "00c4e5796c4e3e1f98ff4adec55d87326d2d2f3c";
    hash = "sha256-Mqxz2P8C8lhS6mVMM9slnnTaF6hRoqjczJH9SjyK83c=";
  };
  unity_catalog = fetchFromGitHub {
    owner = "duckdb";
    repo = "unity_catalog";
    rev = "cc59382f5292997293a57c2ab336c9aa97c05f2d";
    hash = "sha256-ckkEODsfQH+hI0QbODWRUOWe9PodsbMxMzkpob/YAM4=";
  };
  vss = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-vss";
    rev = "3685131eacaf0d467d430be5c4e5e7d1d483437a";
    hash = "sha256-aNf65cZSR3S1JU5SNOSKuvlx436G81lSLRvzyCbWtkk=";
  };
}
