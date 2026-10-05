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
    rev = "28c853c084a6e3acd36d7b8018c42438bb8c5a33";
    hash = "sha256-6FIdsmzzkpUnhxVzN5hd9wuQMPPl9VifoCQjttCJG8M=";
  };

  buildInputs = [
    aws-sdk-cpp-minimal
    curl
    openssl
    zlib
  ];
}
