{
  bzip2,
  expat,
  fetchFromGitHub,
  minizip-ng,
  mkExtension,
  openssl,
  xz,
  zlib,
  zstd,
}:

mkExtension {
  name = "excel";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-excel";
    rev = "f4c72b5ef04a03b3a78a95b5a2ee94ba93e3178d";
    hash = "sha256-hyHTiTfRR+hXJ7hZKt/h/Hu1zNgEYEbMozIv6WZbnfA=";
  };

  buildInputs = [
    bzip2
    expat
    minizip-ng
    openssl
    xz
    zlib
    zstd
  ];
}
