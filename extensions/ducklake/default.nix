{
  extensionSources,
  mkExtension,

  croaring,
}:

mkExtension {
  linkCmake = ''
    find_package(roaring CONFIG REQUIRED)
    target_link_libraries(duckdb PRIVATE roaring::roaring)
  '';

  name = "ducklake";

  src = extensionSources.ducklake;

  buildInputs = [
    croaring
  ];
}
