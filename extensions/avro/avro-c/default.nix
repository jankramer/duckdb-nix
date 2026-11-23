{
  cmake,
  fetchFromGitHub,
  jansson,
  pkg-config,
  snappy,
  stdenv,
  xz,
  zlib,
}:

stdenv.mkDerivation rec {
  pname = "avro-c";
  version = "1.11.3-aad036b";

  # Same avro-c commit as the DuckDB 2.0.1 Avro submodule, including writer cleanup APIs.
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-avro-c";
    rev = "aad036b7ad5d1eb183e68162132cf85e3bfba138";
    hash = "sha256-i8wppwEyfifoXce0eJUVGWEqDRc2ERzQDFwocVJe5Ec=";
  };

  sourceRoot = "${src.name}/lang/c";

  # Still needed by the DuckDB Avro fork with GCC 15's C23 default.
  patches = [ ./gcc15_fix.patch ];
  patchFlags = [ "-p3" ];

  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.10"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
  ];

  buildPhase = ''
    runHook preBuild
    cmake --build . --parallel "$NIX_BUILD_CORES" --target avro-static
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib" "$out/include"
    cp src/libavro.a "$out/lib/"
    cp ../src/avro.h "$out/include/"
    cp -R ../src/avro "$out/include/"
    runHook postInstall
  '';

  postPatch = ''
    patchShebangs .
  '';

  nativeBuildInputs = [
    pkg-config
    cmake
  ];

  buildInputs = [
    jansson
    snappy
    xz
    zlib
  ];
}
