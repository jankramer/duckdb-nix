#include "duckdb.h"
#include <stdio.h>
#include <string.h>

int main(void) {
    if (strcmp(duckdb_library_version(), "v2.0.0") != 0) return 1;
    for (int i = 0; i < 2; ++i) {
        duckdb_database db = NULL;
        duckdb_connection connection = NULL;
        duckdb_result result;
        if (duckdb_open(NULL, &db) != DuckDBSuccess) return 2;
        if (duckdb_connect(db, &connection) != DuckDBSuccess) return 3;
        if (duckdb_query(connection,
            "SELECT json_extract('{\"answer\":42}', '$.answer')::INTEGER",
            &result) != DuckDBSuccess) return 4;
        int valid = duckdb_row_count(&result) == 1 && duckdb_value_int32(&result, 0, 0) == 42;
        duckdb_destroy_result(&result);
        duckdb_disconnect(&connection);
        duckdb_close(&db);
        if (!valid) return 5;
    }
    puts("PASS C API: two database instances, composed JSON extension");
    return 0;
}
