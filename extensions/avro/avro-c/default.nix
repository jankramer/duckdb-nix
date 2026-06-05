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
  version = "1.11.3";

  # https://github.com/duckdb/vcpkg-duckdb-ports/blob/main/ports/avro-c/portfile.cmake#L24
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-avro-c";
    rev = "8af400279c445a81b8552a7670d8c1ebd92ba34a";
    hash = "sha256-LaRdDinWkoXjUp/Z8Fyi5gQ2syB8ptaPA/y1oO+mYrA=";
  };

  sourceRoot = "${src.name}/lang/c";

  patches = [
    ./gcc15_fix.patch
    ./static_lib_only.patch
  ];

  patchFlags = [ "-p3" ];

  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.10"
  ];


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
