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
    rev = "e6a3bd0a8554b74d97cbc7e8acc3e2c9f01a0385";
    hash = "sha256-KmPjETF5G/wU/y2pPyfro6vvTGF4SXO9DHPQfMi04Rs=";
  };

  buildInputs = [
    croaring
  ];
}
