{
  callPackage,
  fetchFromGitHub,
  lib,
  mkExtension,
  pkgsStatic,

  jansson,
  snappy,
  xz,
  zlib,
}:

let
  avro-c = callPackage ./avro-c { };

in
mkExtension {
  name = "avro";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-avro";
    rev = "7f423d69709045e38f8431b3470e0395fce1a595";
    hash = "sha256-jB/eZjtEHhFmuonU9fDYNBiPFoxzpgOaqzQNV36a6GQ=";
  };

  buildInputs = [
    avro-c
    (jansson.overrideAttrs (
      finalAttrs: previousAttrs: {
        cmakeFlags = builtins.filter (flag: !lib.hasInfix "SHARED_LIBS" flag) previousAttrs.cmakeFlags;
      }
    ))
    (snappy.override { static = true; })
    (xz.override { enableStatic = true; })
    zlib.static
  ];
}
