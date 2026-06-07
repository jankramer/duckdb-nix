{
  aws-sdk-cpp,
  callPackage,
  croaring,
  curl,
  fetchFromGitHub,
  mkExtension,
  openssl,
}:

mkExtension {
  name = "iceberg";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-iceberg";
    rev = "4008894c57168e0e9dff00e87cd725c5168fd81e";
    hash = "sha256-wjdQa/SnU2fkSlPKSPygx9EnH0pBolMDAEcw8x5oB5A=";
  };

  buildInputs = [
    aws-sdk-cpp
    croaring
    curl
    openssl
  ];
}
