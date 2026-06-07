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
    rev = "2ad247d4ca090cd2110f2e35531ab6fcdb80c186";
    hash = "sha256-EcEaWa3+Q5OdbasrXqKJMNwKTw9QIYk8PiRq+sYh8ao=";
  };

  buildInputs = [
    azure-sdk-for-cpp.identity
    azure-sdk-for-cpp.storage-blobs
    azure-sdk-for-cpp.storage-files-datalake
  ];
}
