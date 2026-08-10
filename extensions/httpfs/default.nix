{
  fetchFromGitHub,
  mkExtension,
  lib,

  curlMinimal,
  openssl,
}:

mkExtension {
  name = "httpfs";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-httpfs";
    rev = "827222fb45a043a7a852d1f7aae46901492a3cda";
    hash = "sha256-sUp7gHI7NzvNUdqpnODmpVgWb5gY0PsIqUXpnKuAzYw=";
  };

  buildInputs = [
    curlMinimal
    openssl
  ];
}
