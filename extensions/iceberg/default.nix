{
  croaring,
  extensionSources,
  mkExtension,
}:

mkExtension {
  name = "iceberg";
  src = extensionSources.iceberg;
  buildInputs = [ croaring ];
  # mbedTLS is already included in the shared engine's whole archive.
  linkCmake = ''
    find_package(roaring CONFIG REQUIRED)
    target_link_libraries(duckdb PRIVATE roaring::roaring)
  '';
}
