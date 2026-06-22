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
      rev = "37006e53a58ddc31eeb96ff95c21f3196e27fcf2";
      hash = "sha256-tJhJE8nDlQUJO9vfwZo5mx8hIRgO4idJH6ftldKcFUQ=";
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
