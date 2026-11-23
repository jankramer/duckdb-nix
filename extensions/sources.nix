# Match the extension revisions and compatibility patches shipped with DuckDB 2.0.1.
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
    rev = "4176191c961fe5c0763976b8b869e30ba0e93054";
    hash = "sha256-6DFuT5Atp74Gz0fbPe/XRQuJAC1d6DFDclOcyxjIm0U=";
  };
  aws = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-aws";
    rev = "1b96925856ded7c9cbde7403fdb3d467d0cdf779";
    hash = "sha256-SQs9ywEBTKAX3sy2R0y3h6SAP9TjARGiAyUzMCHLFiA=";
  };
  azure = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-azure";
    rev = "bf93a0af8f28fff67c0084c438d20124fd810948";
    hash = "sha256-7cdGLJF5B/4dmLXFNfO8KSBPHdBFgL9F3ng8qbJONkM=";
  };
  ducklake = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "ducklake";
      rev = "08089b16dc8a18ce04abb6efd87e25cb4d64803a";
      hash = "sha256-T4XA2TrADtdhW3axrn5nytWEC27QeBYDXFReergDm2c=";
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
        + "/.github/patches/extensions/ducklake/0023-skip-murmur3-small-numeric-types-on-windows.patch"
      )
      (duckdb-src + "/.github/patches/extensions/ducklake/0028-nested-schema-capability-error.patch")
      (
        duckdb-src + "/.github/patches/extensions/ducklake/0029-ordered-copy-rotates-in-batch-writer.patch"
      )
      (
        duckdb-src
        + "/.github/patches/extensions/ducklake/0030-drop-macro-test-last-schema-name-resolution.patch"
      )
      (duckdb-src + "/.github/patches/extensions/ducklake/0031-table-changes-tests-load-icu.patch")
      (
        duckdb-src
        + "/.github/patches/extensions/ducklake/0032-sqlite-locked-commit-without-sql-in-error.patch"
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
      rev = "623ee80e0bd5a771347f7dd320915cc3ef2fb965";
      hash = "sha256-6uQnLho05QmIC2CKTwqx4fvKTP6wJ3mibpz63QSP968=";
    };
    patches = [
      (duckdb-src + "/.github/patches/extensions/fts/0001-get-default-schema-optional.patch")
      (duckdb-src + "/.github/patches/extensions/fts/0002-fts-indexing-includes.patch")
      (duckdb-src + "/.github/patches/extensions/fts/0003-pragma-function-signature-options.patch")
      (duckdb-src + "/.github/patches/extensions/fts/0004-shorten-persistence-test-extension-dirs.patch")
      (
        duckdb-src
        + "/.github/patches/extensions/fts/0005-autoload-json-before-creating-indexes-in-tests.patch"
      )
      (duckdb-src + "/.github/patches/extensions/fts/0006-skip-persistence-test-under-autoloading.patch")
    ];
  };
  iceberg = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-iceberg";
    rev = "f979b5b28a044c49c38a26636ac01bc1f7047fa5";
    hash = "sha256-gwYRha9c3ToO/cTxLdcxGK4wR2vYjVr6aYIs2Z83zOA=";
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
      rev = "e04d8eef94c94e70c5d5663895610b1bb475d506";
      hash = "sha256-C5B+/mE847FRfkAWIxe1bBynMGyaz4pAYMd6PhxEW3g=";
    };
    postPatch = ''
      cp -R ${databaseConnector}/. database-connector/
    '';
  };
  odbc_scanner = fetchFromGitHub {
    owner = "duckdb";
    repo = "odbc-scanner";
    rev = "ef4382fbfcb238e3012373384ae4e1953f3736a3";
    hash = "sha256-7sja9Sqfm0bmYixmQQ5AaGF/bSOZVePuo1ybZKTRCjc=";
  };
  postgres_scanner = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-postgres";
      rev = "8b9d0bbe8de4c57fb90d9e2530f9ce39f8c4baf3";
      hash = "sha256-SdjIeRIFhoVHrBaRhWVuNr1M5DYxe7L6pQZbbnm6CnY=";
    };
    postPatch = ''
      cp -R ${databaseConnector}/. database-connector/
    '';
  };
  quack = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-quack";
    rev = "3bc63c01f80a13d57ca02a721dd13908c1d934c1";
    hash = "sha256-DnmliMjsx2pgan7RVKT35Y2Ohj4mISDqKxFOYF/TWkY=";
  };
  sqlite_scanner = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-sqlite";
      rev = "ce0987fda4f6393231c6783ee32f72ab873a6d3e";
      hash = "sha256-KgYk1WWuPmzxm4kZ+IvN+hZIzCVV66BX3Yxnt7lgrnE=";
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
    rev = "4cca9f7efd00930039134693e7cbd09fc4771acb";
    hash = "sha256-nC3IAt0S6MWCCyxEHMZZkOLFHCeqb6sJis7RYq4+pq8=";
  };
  vss = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-vss";
    rev = "3685131eacaf0d467d430be5c4e5e7d1d483437a";
    hash = "sha256-aNf65cZSR3S1JU5SNOSKuvlx436G81lSLRvzyCbWtkk=";
  };
}
