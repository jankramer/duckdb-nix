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
    rev = "4bc690dba4496c765777a0269d48fdbaff7cdc11";
    hash = "sha256-cOZf828TAiv3MMwO1fiv0OYiSBeloZ2xGVm4cKQKOtQ=";
  };

  buildInputs = [
    curlMinimal
    openssl
  ];
}
