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
      rev = "45163a28e0ed6a2071a82a1bf1dd432d0216cf9c";
      hash = "sha256-g7H0kKFjuiQ7LL3HvWe0PJYeAzlfh9f71JVVfz4zkWI=";
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
