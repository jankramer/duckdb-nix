{
  cargo,
  fetchFromGitHub,
  mkExtension,
  rustc,
}:

mkExtension {
  name = "delta";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-delta";
    rev = "2d76d40cffa5a8cee04e6fbfb9131c170e471129";
    hash = "sha256-z0EBbSw2xUItpP0/CnOJhBe0dZENNPlX+izIBmWzenM=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cargo
    rustc
  ];
}
