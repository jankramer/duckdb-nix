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
  version = "1.11.3-51ab9b2";

  # Same avro-c commit as the DuckDB 2.0 Avro submodule, including metadata APIs.
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-avro-c";
    rev = "51ab9b2d38d990dcf9629288fd308a674199ec2e";
    hash = "sha256-+DbgVayOG1BjnzkJ7RuEXHVT7ANHWa3sNG79Yjvb3Mc=";
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
