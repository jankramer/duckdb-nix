{
  azure-sdk-for-cpp,
  fetchFromGitHub,
  mkExtension,
}:

mkExtension {
  name = "azure";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-azure";
    rev = "563589b2f24290a4dcdd4247eaedf2b544f9dbcd";
    hash = "sha256-4gnj1OCdyhFosaCPVmiyFx9nSCSemNRxIC+nmVwtHjs=";
  };

  buildInputs = [
    azure-sdk-for-cpp.identity
    azure-sdk-for-cpp.storage-blobs
    azure-sdk-for-cpp.storage-files-datalake
  ];
}
