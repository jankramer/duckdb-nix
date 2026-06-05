{
  callPackage,
  fetchFromGitHub,
  mkExtension,
  openssl,
  libpq,
  lib,
}:

mkExtension {
  name = "postgres";
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-postgres";
    rev = "6b2b12cad3afef61e8a4637e714e8a88895fed1a";
    hash = "sha256-1n4h9RGdbbpd0iCUdyytFxCE+x8tgXp6c/miakz9gYc=";
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
