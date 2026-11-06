{
  fetchFromGitHub,
  mkExtension,

  curlMinimal,
  openssl,
}:

mkExtension {
  name = "httpfs";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-httpfs";
    rev = "77392a72077a85897db2519fae11e2c0da972b8a";
    hash = "sha256-Ni2stJrRSbTkHs+SjfuumtrhIVO917Q9uh91O2YalPM=";
  };

  linkCmake = ''
    find_package(CURL REQUIRED)
    find_package(OpenSSL REQUIRED)
    target_link_libraries(duckdb PRIVATE CURL::libcurl OpenSSL::SSL OpenSSL::Crypto)
    if(APPLE)
      find_library(COREFOUNDATION_FRAMEWORK CoreFoundation REQUIRED)
      find_library(SECURITY_FRAMEWORK Security REQUIRED)
      target_link_libraries(duckdb PRIVATE ''${COREFOUNDATION_FRAMEWORK} ''${SECURITY_FRAMEWORK})
    endif()
  '';

  buildInputs = [
    curlMinimal
    openssl
  ];
}
