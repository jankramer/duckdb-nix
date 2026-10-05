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
    rev = "318dabb2474fc3789b0199301a2e661e19c1b4fc";
    hash = "sha256-Sn3xXJH2EHc6ecdKcw15/MMi8xnMPhJRZ8Cg+zlvV5o=";
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
