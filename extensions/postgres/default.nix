{
  callPackage,
  fetchFromGitHub,
  mkExtension,
  openssl,
  libpq,
  lib,
}:

mkExtension {
  name = "postgres_scanner";
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-postgres";
    rev = "8f813f9b9c9e52a9074a050a0be60f49160a6baa";
    hash = "sha256-BICWevTyfE0N6vBirGIwa6EgPnyDkKHnMD+igv4XzZ0=";
    fetchSubmodules = true;
  };

  buildInputs = [
    openssl
    (libpq.override {
      curlSupport = false;
      gssSupport = false;
      nlsSupport = false;
    })
  ];
}
