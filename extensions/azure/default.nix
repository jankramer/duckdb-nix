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
    rev = "003214c96d0caa39d5c3e27a9e1976a0692c7d37";
    hash = "sha256-+d0jF+kzxhcIf6HWgn1FRotPalH2ZYnb1rdXpsJmhAc=";
  };

  buildInputs = [
    azure-sdk-for-cpp.identity
    azure-sdk-for-cpp.storage-blobs
    azure-sdk-for-cpp.storage-files-datalake
  ];
}
