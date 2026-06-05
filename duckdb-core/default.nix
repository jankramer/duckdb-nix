{
  callPackage,
  cmake,
  lib,
  ninja,
  python3,
  stdenv,

  duckdb-src,
}:

stdenv.mkDerivation {
  pname = "duckdb-core";
  version = duckdb-src.version;

  src = duckdb-src;

  nativeBuildInputs = [
    cmake
    ninja
    python3
  ];

  NIX_CFLAGS_COMPILE = [
    "-DDUCKDB_ALLOW_UNSIGNED_NIX_STORE_EXTENSIONS"
  ];

  cmakeFlags = [
    (lib.cmakeFeature "SKIP_EXTENSIONS" "core_functions;parquet")
    (lib.cmakeFeature "OVERRIDE_GIT_DESCRIBE" duckdb-src.gitDescribe)
    (lib.cmakeBool "ENABLE_EXTENSION_AUTOLOADING" true)
    (lib.cmakeBool "BUILD_UNITTESTS" false)
  ];

  outputs = [
    "out"
    "dev"
  ];

  postInstall = ''
    moveToOutput "lib/*.a" "$dev"
  '';

  postFixup = ''
    files=(
      "$dev/lib/cmake/DuckDB/DuckDBExports-release.cmake"
      "$dev/lib/cmake/DuckDB/DuckDBExports.cmake"
    )

    # Escape values before interpolating them into a sed regex/replacement.
    outRe=$(printf '%s' "$out" | sed -e 's/[.[\*^$()+?{}|\\]/\\&/g')
    devRep=$(printf '%s' "$dev" | sed -e 's/[&@\\]/\\&/g')

    for f in "''${files[@]}"; do
      sed -E -i \
        "s@''${outRe}(/[^\"';[:space:]]+\.a)@''${devRep}\1@g" \
        "$f"

      # Optional: fail if any .a references to $out remain.
      if grep -nE "''${outRe}/[^\"';[:space:]]+\.a" "$f"; then
        echo "failed to rewrite all .a references from $out to $dev in $f" >&2
        exit 1
      fi
    done
  '';
}
