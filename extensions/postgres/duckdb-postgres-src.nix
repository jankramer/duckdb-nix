{
  fetchFromGitHub,
  lib,
  openssl,
  readline,
  stdenv,
  zlib,
}:

let
  postgres-src = fetchFromGitHub {
    owner = "postgres";
    repo = "postgres";
    rev = "REL_15_13";
    hash = "sha256-6guX2ms54HhJJ0MoHfQb5MI9qrcA0niJ06oa1glsFuY=";
  };

in

stdenv.mkDerivation {
  name = "duckdb-postgres-src";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-postgres";
    rev = "c0e9256a60371a062e8d6cfc4045c71a317b5ee8";
    hash = "sha256-HsFrZCjAxCNfQ0OUwB1FS3xv08/OURDHFXuxMjSKFIc=";
  };

  buildPhase = "
    cp -R ${postgres-src} ./postgres
    chmod -R +w ./postgres
    pushd postgres
    ./configure --without-llvm --without-icu --without-tcl --without-perl --without-python --without-gssapi --without-pam --without-bsd-auth --without-ldap --without-bonjour --without-selinux --without-systemd --without-readline --without-libxml --without-libxslt --without-zlib --without-lz4 --without-openssl
    popd

    mkdir -p $out
    cp -R ./* $out/

  ";

  installPhase = ":";
}
