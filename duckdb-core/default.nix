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

  # Move static libraries to dev output and update their paths in cmake files
  postInstall = ''
    find $out -name '*.a' -exec bash -c 'sed -i "s|$1|''${1/$out/$dev}|g" '$out'/lib/cmake/**/*.cmake' x {} \;
    moveToOutput "lib/*.a" "$dev"
  '';
}
