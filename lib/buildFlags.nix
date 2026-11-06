# Keep the engine and independently compiled extensions on the same ABI/profile.
{ duckdb-src }:
[
  "-DBUILD_UNITTESTS=OFF"
  "-DSTATICALLY_LINK_EXTENSIONS=none"
  "-DDUCKDB_CAPABILITIES=none"
  "-DENABLE_EXTENSION_LOAD=OFF"
  "-DENABLE_BUILTIN_HTTPLIB=OFF"
  "-DENABLE_JEMALLOC=OFF"
  "-DDUCKDB_OPTIMIZATION_PROFILE=NONE"
  "-DDUCKDB_EXPLICIT_VERSION=v${duckdb-src.version}"
  "-DGIT_COMMIT_HASH=${duckdb-src.gitRevision}"
]
