{
  applyPatches,
  extensionSources,
  mkExtension,
  unixodbc,
}:

mkExtension {
  linkCmake = ''
    find_package(ODBC REQUIRED)
    find_library(ODBCINST_LIBRARY NAMES odbcinst REQUIRED)
    target_link_libraries(duckdb PRIVATE ODBC::ODBC ''${ODBCINST_LIBRARY})
  '';

  name = "odbc_scanner";

  src = applyPatches {
    src = extensionSources.odbc_scanner;
    postPatch = ''
      cp ${./CMakeLists.txt} CMakeLists.txt
      cp ${./capi_entry_point.cpp} src/capi_entry_point.cpp
    '';
  };

  buildInputs = [ unixodbc ];
}
