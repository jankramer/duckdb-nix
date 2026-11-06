{
  cmake,
  ninja,
  python3,
  stdenv,
  duckdb-src,
}:

stdenv.mkDerivation {
  pname = "duckdb-core";
  version = duckdb-src.version;
  src = duckdb-src;
  nativeBuildInputs = [
    cmake
    ninja
    python3
  ];
  # No extension is part of this reusable engine, including the upstream defaults.
  preConfigure = "echo > extension/extension_config.cmake";
  cmakeFlags = (import ../lib/buildFlags.nix { inherit duckdb-src; }) ++ [ "-DBUILD_SHELL=ON" ];
  buildPhase = ''
    runHook preBuild
    cmake --build . --parallel "$NIX_BUILD_CORES" --target duckdb_static duckdb_shell
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib"
    cp src/libduckdb_static.a src/libduckdb_shell.a "$out/lib/"
    runHook postInstall
  '';
}
