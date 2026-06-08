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
      rev = "4008894c57168e0e9dff00e87cd725c5168fd81e";
      hash = "sha256-wjdQa/SnU2fkSlPKSPygx9EnH0pBolMDAEcw8x5oB5A=";
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
