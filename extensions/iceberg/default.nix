{
  applyPatches,
  aws-sdk-cpp,
  callPackage,
  croaring,
  curl,
  fetchFromGitHub,
  mkExtension,
  openssl,
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
  name = "iceberg";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "duckdb";
      repo = "duckdb-iceberg";
      rev = "e6fe0a4b28ed13f4a1ae5c7e12bad338c6fc13c7";
      hash = "sha256-R6+q6vw7ik0H6dN0QlsZFNXExp4YMlSvuVMOgM8o12E=";
    };

    patches = [
      ./link-duckdb-mbedtls.patch
    ];
  };

  buildInputs = [
    aws-sdk-cpp-minimal
    croaring
    curl
    openssl
  ];
}
