{
  applyPatches,
  fetchFromGitHub,
  lib,
  libmysqlclient,
  mkExtension,
  openssl,
  zlib,
}:

mkExtension {
  name = "mysql_scanner";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-mysql";
      rev = "7267164dab3409e943261aeee6ae32f1b00847a7";
      hash = "sha256-Zx2QzzisoGsQ95t2Gck+akFt30GRhjWXffuyUh3GdLU=";
      fetchSubmodules = true;
    };

    postPatch = ''
      cat > vcpkg_ports/libmariadb/libmariadb-config.cmake <<'EOF'
      find_library(MYSQL_LIBRARIES NAMES mariadb libmariadb PATHS "${libmysqlclient}/lib/mariadb" NO_DEFAULT_PATH REQUIRED)
      set(libmariadb_FOUND 1)
      EOF

      substituteInPlace CMakeLists.txt \
        --replace-fail '    ''${CMAKE_BINARY_DIR}/vcpkg_installed/''${VCPKG_TARGET_TRIPLET}/include/mysql)' \
                       '    ${libmysqlclient.dev}/include/mariadb)'
    '';
  };

  buildInputs = [
    libmysqlclient
    openssl
    zlib
  ];

  cmakeFlags = [
    (lib.cmakeFeature "libmariadb_DIR" "${libmysqlclient}/lib/mariadb")
  ];
}
