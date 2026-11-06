#include "capi_entry_point.hpp"

DUCKDB_EXTENSION_ENTRYPOINT(duckdb_connection connection, duckdb_extension_info info,
                           duckdb_extension_access *access) {
    return initiaize_odbc_scanner(connection, info, access);
}
