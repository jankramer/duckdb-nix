{
  azure-sdk-for-cpp,
  extensionSources,
  mkExtension,
}:

mkExtension {
  linkCmake = ''
    find_package(azure-identity-cpp CONFIG REQUIRED)
    find_package(azure-storage-blobs-cpp CONFIG REQUIRED)
    find_package(azure-storage-files-datalake-cpp CONFIG REQUIRED)
    target_link_libraries(duckdb PRIVATE Azure::azure-identity Azure::azure-storage-blobs Azure::azure-storage-files-datalake)
  '';

  name = "azure";

  src = extensionSources.azure;

  buildInputs = [
    azure-sdk-for-cpp.identity
    azure-sdk-for-cpp.storage-blobs
    azure-sdk-for-cpp.storage-files-datalake
  ];
}
