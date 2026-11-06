{
  aws-sdk-cpp,
  curl,
  extensionSources,
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
      "redshift"
      "redshift-serverless"
      "cloudformation"
      "sso"
      "sts"
    ];
  };
in

mkExtension {
  linkCmake = ''
    find_package(ZLIB REQUIRED)
    find_package(AWSSDK REQUIRED COMPONENTS core sso sts identity-management rds redshift redshift-serverless cloudformation)
    target_link_libraries(duckdb PRIVATE ''${AWSSDK_LINK_LIBRARIES})
  '';

  name = "aws";

  src = extensionSources.aws;

  buildInputs = [
    aws-sdk-cpp-minimal
    curl
    openssl
    zlib
  ];
}
