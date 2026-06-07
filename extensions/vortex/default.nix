{
  applyPatches,
  cargo,
  corrosion,
  fetchFromGitHub,
  mkExtension,
  rustc,
}:

mkExtension {
  name = "vortex";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "vortex-data";
      repo = "duckdb-vortex";
      rev = "5a78c9abd3b8f45a99dded142fb985dfb111a0a4";
      hash = "sha256-LZ2miwv1/Tg8whEz5IsBCh3+68E7ieRDU+8vMqDy01I=";
      fetchSubmodules = true;
    };

    patches = [ ./use-packaged-corrosion.patch ];
  };

  nativeBuildInputs = [
    cargo
    corrosion
    rustc
  ];
}
