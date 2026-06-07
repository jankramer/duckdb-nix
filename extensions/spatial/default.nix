{
  curl,
  expat,
  fetchFromGitHub,
  gdal,
  geos,
  lib,
  mkExtension,
  openssl,
  proj,
  sqlite,
  zlib,
}:

mkExtension {
  name = "spatial";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-spatial";
    rev = "b68b309d371dba936c5bb362980e559b7756b16d";
    hash = "sha256-cSsdHVM1yDSCZuwXKv9N/P1PFI8vY+7EtHNosIP5PGg=";
  };

  buildInputs = [
    curl
    expat
    gdal
    geos
    openssl
    proj
    sqlite
    zlib
  ];

  cmakeFlags = [
    (lib.cmakeBool "SPATIAL_USE_NETWORK" true)
  ];
}
