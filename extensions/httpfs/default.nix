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
    rev = "f71cfdb4bff85b9e15b1f3b842d9aa395aff0167";
    hash = "sha256-rTG5cQlvwvyfPWnLTvuUmUH0sEfjbQiyInHCKtM0Q9U=";
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
