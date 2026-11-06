{
  cmake,
  duckdb-src,
  fetchFromGitHub,
  jdk,
  lib,
  ninja,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "duckdb-java";
  version = "2.0.0.0";
  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-java";
    rev = "eb43895e47788e398a7a64c16505046364fa75ea";
    hash = "sha256-V626XOGYWTcTyTszbtlWmEXkkzoWnl7RkbCcDGHfDbY=";
  };
  nativeBuildInputs = [
    cmake
    ninja
    jdk
  ];
  JAVA_HOME = "${jdk}";
  postPatch = "cp ${./CMakeLists.txt} CMakeLists.txt";
  cmakeFlags = [ "-DDUCKDB_SOURCE=${duckdb-src}" ];
  meta = {
    description = "Reusable DuckDB JDBC classes and JNI objects";
    homepage = "https://github.com/duckdb/duckdb-java";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
