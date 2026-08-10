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
      rev = "7612d198de85dee10ffd6e818fb51174eb0a1da1";
      hash = "sha256-Me+ACBNiYbDFDHkoCGo8NR0S5vlpYegAPEsI1Z5RPzw=";
    };
    patches = [ ./adc_fallback.patch ];
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

  filePrefixes = [
    "gs://"
    "gcss://"
  ];
}
