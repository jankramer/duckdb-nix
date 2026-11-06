{
  extensionSources,
  mkExtension,
  openssl,
  libpq,
}:

mkExtension {
  linkCmake = ''
    find_package(OpenSSL REQUIRED)
    find_package(PostgreSQL REQUIRED)
    target_link_libraries(duckdb PRIVATE OpenSSL::SSL OpenSSL::Crypto PostgreSQL::PostgreSQL)
  '';

  name = "postgres_scanner";
  src = extensionSources.postgres_scanner;

  buildInputs = [
    openssl
    (libpq.override {
      curlSupport = false;
      gssSupport = false;
      nlsSupport = false;
    })
  ];
}
