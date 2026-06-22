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
    rev = "40de7badae4193c29d9c0834473fb76acc6c51e6";
    hash = "sha256-E33EiV/SYD6l1kHiCNgkt/d15FT8hNM53pNPQgsMEqA=";
  };

  buildInputs = [
    curlMinimal
    openssl
  ];
}
