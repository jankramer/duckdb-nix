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
    rev = "7e80f7ffcc98d0b3e81d0e1df8cc1c2da240a64b";
    hash = "sha256-fLswkJMvfhv8yAsWIiZvG6Lg5Svy8d8d8+WmPiWt4AI=";
  };

  buildInputs = [
    curlMinimal
    openssl
  ];
}
