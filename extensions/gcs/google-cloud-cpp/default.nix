{
  abseil-cpp,
  cmake,
  curl,
  fetchFromGitHub,
  grpc,
  gtest,
  lib,
  ninja,
  nlohmann_json,
  openssl,
  opentelemetry-cpp,
  pkg-config,
  protobuf,
  replaceVars,
  stdenv,
}:
let
  googleapis = fetchFromGitHub {
    name = "googleapis-src";
    owner = "googleapis";
    repo = "googleapis";
    # defined in cmake/GoogleapisConfig.cmake
    rev = "20ac242a6b3a723cb10c1a0201209261addaf7d8";
    hash = "sha256-qFsDk69OHEure7EB2hLHJVARkDQPuZ8YH3gY7pu14fs=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "google-cloud-cpp";
  version = "3.5.0";

  src = fetchFromGitHub {
    owner = "googleapis";
    repo = "google-cloud-cpp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-I9UTJTLZb+yDQE2Re4t5OwJMOduAJz4d8vZ7dBXUenQ=";
  };

  patches = [
    (replaceVars ./hardcode-googleapis-path.patch {
      url = googleapis;
    })
  ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    gtest
  ];

  buildInputs = [
    abseil-cpp
    grpc
    curl
    openssl
    nlohmann_json
    protobuf
    opentelemetry-cpp
  ];

  cmakeFlags = [
    "-DGOOGLE_CLOUD_CPP_ENABLE=storage_grpc"
    "-DGOOGLE_CLOUD_CPP_ENABLE_EXAMPLES=OFF"
    "-DGOOGLE_CLOUD_CPP_ENABLE_MACOS_OPENSSL_CHECK=OFF"
  ];
})
