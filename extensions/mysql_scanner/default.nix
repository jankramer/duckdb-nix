{
  fetchFromGitHub,
  lib,
  libmysqlclient,
  mkExtension,
  openssl,
  zlib,
}:

mkExtension {
  name = "mysql_scanner";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-mysql";
    rev = "496ac9e3cb61bd8d6d1255f73cf69b958a311525";
    hash = "sha256-V3l+LE/dHpYljvCstf7dvrekWIqtN/w314qxjrLNnVw=";
    fetchSubmodules = true;
  };

  buildInputs = [
    libmysqlclient
    openssl
    zlib
  ];

  cmakeFlags = [
    (lib.cmakeFeature "libmariadb_DIR" "${libmysqlclient}/lib/mariadb")
  ];
}
