{
  applyPatches,
  callPackage,
  fetchFromGitHub,
  lib,
  mkExtension,

  abseil-cpp_202601,
  curlMinimal,
  grpc,
  nlohmann_json,
  opentelemetry-cpp,
  protobuf,
}:

let
  enableStaticBuild = finalAttrs: previousAttrs: {
    cmakeFlags = map (builtins.replaceStrings
      [ "BUILD_SHARED_LIBS=ON" "BUILD_SHARED_LIBS:BOOL=ON" ]
      [ "BUILD_SHARED_LIBS=OFF" "BUILD_SHARED_LIBS:BOOL=OFF" ]
    ) previousAttrs.cmakeFlags;
  };

  staticLibs = {
    abseil-cpp = abseil-cpp_202601.override { static = true; };
    grpc = (grpc.overrideAttrs enableStaticBuild);
    opentelemetry-cpp =
      (opentelemetry-cpp.overrideAttrs (prev: {
        cmakeFlags = (lib.lists.drop 1 prev.cmakeFlags) ++ [
          "-DBUILD_SHARED_LIBS:BOOL=OFF"
          "-DBUILD_TESTING:BOOL=OFF"
          "-DWITH_EXAMPLES:BOOL=OFF"
        ];
        doCheck = false;
      })).override
        {
          cxxStandard = "17";
        };
    protobuf = (protobuf.override { enableShared = false; }).overrideAttrs { doCheck = false; };
  };

  google-cloud-cpp = (callPackage ./google-cloud-cpp staticLibs);

in

mkExtension {
  name = "gcs";

  src = applyPatches {
    src = fetchFromGitHub {
      owner = "northpolesec";
      repo = "duckdb-gcs";
      rev = "f55eef6635f5b613d7cb90a98fe2ed7afcd0f0c8";
      hash = "sha256-QefFjTkZqNYgj3YRTa0ST10G4gUvZBT+hY5mwEu2Dmg=";
    };
    patches = [
      ./adc_fallback.patch
      ./register-options.patch
      ./list-errors.patch
    ];
  };

  buildInputs = [
    staticLibs.abseil-cpp
    staticLibs.grpc
    staticLibs.opentelemetry-cpp
    staticLibs.protobuf
    google-cloud-cpp

    curlMinimal
    nlohmann_json
  ];

  registrationSources = [ ./settings.cpp ];
  linkCmake = ''
    find_package(google_cloud_cpp_storage REQUIRED)
    find_package(google_cloud_cpp_storage_grpc REQUIRED)
    target_link_libraries(duckdb PRIVATE google-cloud-cpp::storage google-cloud-cpp::storage_grpc)
  '';

  filePrefixes = [
    "gs://"
    "gcss://"
  ];
}
