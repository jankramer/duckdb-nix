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
    rev = "41223e51559cd581f1c06e170b71c71df25bbaac";
    hash = "sha256-P9GlAkUmYN/UOQ/B1RW7Cr75kpiYfqF49WfPWgCPjOU=";
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
