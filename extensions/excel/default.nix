{
  bzip2,
  expat,
  extensionSources,
  minizip-ng,
  mkExtension,
  openssl,
  xz,
  zlib,
  zstd,
}:

mkExtension {
  linkCmake = ''
    find_package(EXPAT REQUIRED)
    find_package(ZLIB REQUIRED)
    find_package(minizip-ng CONFIG REQUIRED)
    target_link_libraries(duckdb PRIVATE EXPAT::EXPAT MINIZIP::minizip-ng ZLIB::ZLIB)
  '';

  name = "excel";

  src = extensionSources.excel;

  buildInputs = [
    bzip2
    expat
    minizip-ng
    openssl
    xz
    zlib
    zstd
  ];
}
