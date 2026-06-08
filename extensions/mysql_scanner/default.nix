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
      rev = "496ac9e3cb61bd8d6d1255f73cf69b958a311525";
      hash = "sha256-V3l+LE/dHpYljvCstf7dvrekWIqtN/w314qxjrLNnVw=";
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
