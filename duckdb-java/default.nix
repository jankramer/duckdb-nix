{
  cmake,
  duckdb-core,
  fetchFromGitHub,
  jdk,
  lib,
  ninja,
  stdenv,
}:

stdenv.mkDerivation {
  pname = "duckdb-java";
  version = "1.5.5.1";

  src = fetchFromGitHub {
    owner = "duckdb";
    repo = "duckdb-java";
    rev = "2641879daaf4ee2c8998d7acfeab474c0a2d382e";
    hash = "sha256-x4YVDIbzlZbdTVf5nbdA/i1P9o//BuDrwEWbguznX5M=";
  };

  patches = [ ./patches/0001-Build-against-external-duckdb.patch ];

  nativeBuildInputs = [
    cmake
    ninja
    jdk
  ];

  buildInputs = [
    duckdb-core
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck

    java -cp duckdb_jdbc_tests.jar:duckdb_jdbc.jar org.duckdb.TestDuckDBJDBC test_connection
    java -Djava.library.path=$PWD -cp duckdb_jdbc_tests.jar:duckdb_jdbc_nolib.jar org.duckdb.TestDuckDBJDBC test_connection

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 duckdb_jdbc_nolib.jar $out/share/java/duckdb_jdbc_nolib.jar
    install -Dm644 duckdb_jdbc.jar $out/share/java/duckdb_jdbc.jar
    install -Dm755 libduckdb_java${stdenv.hostPlatform.extensions.sharedLibrary} -t $out/lib

    runHook postInstall
  '';

  meta = {
    description = "DuckDB JDBC driver linked against the packaged DuckDB shared library";
    homepage = "https://github.com/duckdb/duckdb-java";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
