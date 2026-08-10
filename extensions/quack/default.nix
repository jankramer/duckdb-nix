{
  fetchFromGitHub,
  mkExtension,
  lib,

  curlMinimal,
  openssl,
}:

mkExtension {
  name = "quack";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-quack";
    rev = "c1548111c1bfd16207e22fd3cb7e4bde1335b9d0";
    hash = "sha256-B94mtDHNemCmPQfZIceIaFYeMy4rjwrV6OzRxK83DkQ=";
  };

  buildInputs = [
    curlMinimal
    openssl
  ];
}
