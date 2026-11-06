{
  applyPatches,
  extensionSources,
  lib,
  libmysqlclient,
  mkExtension,
  openssl,
  zlib,
}:

mkExtension {
  linkCmake = ''
    find_library(MARIADB_LIBRARY NAMES mariadb PATHS "${libmysqlclient}/lib/mariadb" NO_DEFAULT_PATH REQUIRED)
    target_link_libraries(duckdb PRIVATE ''${MARIADB_LIBRARY})
  '';

  name = "mysql_scanner";

  src = applyPatches {
    src = extensionSources.mysql_scanner;

    postPatch = ''
      # Keep these helpers local when MySQL and PostgreSQL share one engine.
      substituteInPlace src/storage/mysql_catalog.cpp \
        --replace-fail 'unique_ptr<SecretEntry> GetSecret(' 'static unique_ptr<SecretEntry> GetSecret('
      substituteInPlace src/storage/mysql_schema_entry.cpp \
        --replace-fail 'bool CatalogTypeIsSupported(' 'static bool CatalogTypeIsSupported('

      cat > vcpkg_ports/libmariadb/libmariadb-config.cmake <<'EOF'
      find_library(MYSQL_LIBRARIES NAMES mariadb libmariadb PATHS "${libmysqlclient}/lib/mariadb" NO_DEFAULT_PATH REQUIRED)
      set(libmariadb_FOUND 1)
      EOF

      substituteInPlace CMakeLists.txt \
        --replace-fail 'build_loadable_extension(' 'build_static_extension(''${TARGET_NAME} ''${ALL_OBJECT_FILES})
      build_loadable_extension('

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
