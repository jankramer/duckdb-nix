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
    rev = "f9d590297485f0318f480372c70bdd852826e258";
    hash = "sha256-1JiLOHgnqd7Oao3S8W2/erlqi8fgvpbHXSURhigBQSM=";
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
