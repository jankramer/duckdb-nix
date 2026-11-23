{
  applyPatches,
  extensionSources,
  mkExtension,
  unixodbc,
}:

mkExtension {
  linkCmake = ''
    target_link_libraries(duckdb PRIVATE "''${EXTENSION_PREFIX}/lib/libduckdb_cpp_api.a" ''${CMAKE_DL_LIBS})
  '';

  name = "odbc_scanner";

  src = applyPatches {
    src = extensionSources.odbc_scanner;
    postPatch = ''
      cp ${./CMakeLists.txt} CMakeLists.txt
      # The driver manager is now loaded with dlopen; resolve it from Nix.
      substituteInPlace src/driver_manager.cpp \
        --replace-fail '"libodbc.2.dylib"' '"${unixodbc}/lib/libodbc.2.dylib"' \
        --replace-fail '"libodbc.so.2"' '"${unixodbc}/lib/libodbc.so.2"'
    '';
  };

  extraArchives = [ "tools/cpp/libduckdb_cpp_api.a" ];

  buildInputs = [ unixodbc ];
}
