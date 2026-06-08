{
  aws-sdk-cpp,
  curl,
  fetchFromGitHub,
  mkExtension,
  openssl,
  zlib,
}:

let
  aws-sdk-cpp-minimal = aws-sdk-cpp.override {
    apis = [
      "core"
      "identity-management"
      "rds"
      "sso"
      "sts"
    ];
  };
in

mkExtension {
  name = "aws";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-aws";
    rev = "38d4ed30b7f5855168f4b494bf9be611c868c69a";
    hash = "sha256-48LuIbzjPE5bG7RTvVYpoonUg0JS8MGyfxh0R/b1NNQ=";
  };

  buildInputs = [
    aws-sdk-cpp-minimal
    curl
    openssl
    zlib
  ];
}
