{
  aws-sdk-cpp,
  curl,
  extensionSources,
  fetchFromGitHub,
  fetchurl,
  mkExtension,
  openssl,
  zlib,
}:

let
  # Runtime revision pinned by SDK 1.11.820, including its C library submodules.
  aws-crt-src = fetchFromGitHub {
    name = "aws-crt-cpp-b540e93";
    owner = "awslabs";
    repo = "aws-crt-cpp";
    rev = "b540e9314f3ecc5a6c592efb07a516a6b20c5bbb";
    fetchSubmodules = true;
    hash = "sha256-g1ywi+J/7vNznYeI8a40x8pQss32dhjfIlYL9BRgzFA=";
  };
  aws-sdk-cpp-minimal =
    (aws-sdk-cpp.override {
      apis = [
        "core"
        "identity-management"
        "rds"
        "redshift"
        "redshift-serverless"
        "cloudformation"
        "s3tables"
        "s3"
        "sso"
        "sts"
      ];
    }).overrideAttrs
      (
        finalAttrs: previousAttrs: {
          # Match DuckDB's vcpkg port: S3 Tables requires newer SDK APIs.
          version = "1.11.820";
          src = fetchFromGitHub {
            owner = "aws";
            repo = "aws-sdk-cpp";
            tag = finalAttrs.version;
            hash = "sha256-gRtW2nQ1eHa6LR2GtzxyIL66lJhETqBiKjCDq7mmzag=";
          };
          patches = (previousAttrs.patches or [ ]) ++ [
            (fetchurl {
              url = "https://raw.githubusercontent.com/duckdb/vcpkg-duckdb-ports/4a39aaaace793e256039aaf0cf4f10a96cfe08b3/ports/aws-sdk-cpp/patches/fix-crt-credentials-expiration.patch";
              hash = "sha256-SRYTU6AzFzSI9POmACNhKtJ2+eBA/Lcet2nOGTtNe2A=";
            })
          ];
          postPatch = previousAttrs.postPatch + ''
            mkdir -p crt/aws-crt-cpp
            cp -R ${aws-crt-src}/. crt/aws-crt-cpp/
            # Keep credential test fixtures inside this build's writable directory.
            substituteInPlace tests/testing-resources/source/TestingEnvironment.cpp \
              --replace-fail 'tempDir << P_tmpdir;' 'tempDir << Aws::Environment::GetEnv("TMPDIR");'
          '';
          # The locked Nixpkgs runtime predates the SDK's login/proxy APIs.
          propagatedBuildInputs = [ ];
          cmakeFlags =
            map (builtins.replaceStrings [ "-DBUILD_DEPS=OFF" ] [ "-DBUILD_DEPS=ON" ]) previousAttrs.cmakeFlags
            ++ [
              "-DUSE_OPENSSL=ON"
              "-DENFORCE_SUBMODULE_VERSIONS=OFF"
              "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
            ];
        }
      );
in

mkExtension {
  linkCmake = ''
    find_package(ZLIB REQUIRED)
    find_package(AWSSDK REQUIRED COMPONENTS core sso sts identity-management rds redshift redshift-serverless cloudformation s3tables s3)
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
