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
    rev = "08ad34f625e4a8e15221e462b96000ff29174447";
    hash = "sha256-ut7+a6PiR5LWyrITEJaC8MLDrtdqtWyjOaP1hqerllA=";
  };

  buildInputs = [
    aws-sdk-cpp-minimal
    curl
    openssl
    zlib
  ];
}
