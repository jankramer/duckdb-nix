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
      rev = "890b78a9cfae380396b435b033c27cdbdad04e42";
      hash = "sha256-9O96m3Bf0C3qgwTbG/8i9pHRVq/ZTKXobeG1bidJB7o=";
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
