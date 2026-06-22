{
  fetchFromGitHub,
  mkExtension,
  lib,

  croaring
}:

mkExtension {
  name = "ducklake";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "ducklake";
    rev = "d318a545571d7d46eb751fa2aa5f6f4389285d3c";
    hash = "sha256-qq+U3+X2cGtw91/WnhJJG2WyWQflkJMuBvGjQ0si2DY=";
  };

  buildInputs = [
    croaring
  ];
}
