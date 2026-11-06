{
  extensionSources,
  mkExtension,

  curlMinimal,
  openssl,
}:

mkExtension {
  linkCmake = ''
    find_package(OpenSSL REQUIRED)
    target_link_libraries(duckdb PRIVATE OpenSSL::SSL OpenSSL::Crypto)
    if(APPLE)
      find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
      find_library(SECURITY_FRAMEWORK Security REQUIRED)
      target_link_libraries(duckdb PRIVATE ''${COREFOUNDATION_FRAMEWORK} ''${SECURITY_FRAMEWORK})
    endif()
  '';

  name = "quack";

  src = extensionSources.quack;

  buildInputs = [
    curlMinimal
    openssl
  ];
}
