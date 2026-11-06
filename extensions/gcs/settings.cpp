// Use DuckDB 2.0's early per-database capability callback for GCS settings.
// GCS's option declarations stay in the extension; there is no generated name/type map here.
#include "duckdb/main/config.hpp"
#include "duckdb/main/database.hpp"
#include "duckdb_static_extension.h"

namespace duckdb {
void RegisterGCSOptions(DBConfig &config);
}

namespace {
void ConfigureGCS(duckdb::DatabaseInstance &db) {
    auto &config = duckdb::DBConfig::GetConfig(db);
    auto pending = config.options.unrecognized_options;
    duckdb::RegisterGCSOptions(config);
    // AddExtensionOption consumes pending values without casting them. GCS's
    // plain options have no callbacks; apply the declared types explicitly.
    for (const auto &option : pending) {
        if (config.HasExtensionOption(option.first)) {
            config.SetOptionByName(option.first, option.second);
        }
    }
}

int32_t DescribeGCSSettings(duckdb_extension_descriptor *descriptor) {
    if (descriptor->version < 2) return 1;
    descriptor->version = 2;
    descriptor->name = "gcs_startup_settings";
    descriptor->extension_version = "2.0.0";
    descriptor->api_version = "v2.0.0";
    descriptor->database_callback = reinterpret_cast<void (*)(void)>(ConfigureGCS);
    return 0;
}

struct RegisterGCSSettings {
    RegisterGCSSettings() { duckdb_register_static_extension(DescribeGCSSettings); }
} register_gcs_settings;
}
