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
    rev = "ac7595b0a1305bea3d4cfaca763b0ce964c763a2";
    hash = "sha256-QtdhWneqq61dvX2KX68mHm/06YZ30xWITIq5fJqCaFc=";
  };

  buildInputs = [
    croaring
  ];
}
