{
  croaring,
  extensionSources,
  mkExtension,
}:

mkExtension {
  buildInputs = [ croaring ];
  linkCmake = ''
    find_package(roaring CONFIG REQUIRED)
    target_link_libraries(duckdb PRIVATE roaring::roaring)
  '';

  name = "unity_catalog";

  src = extensionSources.unity_catalog;
}
