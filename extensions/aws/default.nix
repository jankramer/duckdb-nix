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
    rev = "efa54a990e16c976576685dd4134d2478cf5a574";
    hash = "sha256-6FIdsmzzkpUnhxVzN5hd9wuQMPPl9VifoCQjttCJG8M=";
  };

  buildInputs = [
    aws-sdk-cpp-minimal
    curl
    openssl
    zlib
  ];
}
