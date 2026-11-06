import java.sql.*;
import java.util.Properties;

public final class GcsSmoke {
    static final String EXPECTED = "autocomplete,core_functions,gcs,httpfs,icu,json,parquet";
    static Properties options() {
        Properties p = new Properties();
        p.setProperty("autoload_known_extensions", "false");
        p.setProperty("autoinstall_known_extensions", "false");
        p.setProperty("gcs_enable_metadata_cache", "false");
        p.setProperty("gcs_metadata_cache_ttl", "12");
        p.setProperty("gcs_list_cache_ttl", "13");
        p.setProperty("gcs_max_metadata_cache_entries", "17");
        p.setProperty("gcs_max_list_cache_entries", "18");
        p.setProperty("gcs_transfer_concurrency", "3");
        p.setProperty("gcs_enable_grpc", "false");
        return p;
    }
    static void rejectOpen(Properties p, String message) throws Exception {
        try (Connection ignored = DriverManager.getConnection("jdbc:duckdb:", p)) {
            throw new AssertionError("Unexpected startup success");
        } catch (SQLException e) {
            if (!e.getMessage().toLowerCase().contains(message.toLowerCase())) throw e;
        }
    }
    static String conflict(String host) {
        return "CREATE SECRET competing_httpfs (TYPE GCS, KEY_ID 'test-hmac', SECRET 'test-hmac', "
            + "ENDPOINT '" + host + "', URL_STYLE 'path', USE_SSL false)";
    }
    public static void main(String[] args) throws Exception {
        Properties p = options();
        // Check types, all declared settings, and repeated independent instances.
        for (boolean autoload : new boolean[] {false, true}) {
            p.setProperty("autoload_known_extensions", Boolean.toString(autoload));
            // The early callback needs no installation or lookup, even with upstream defaults.
            p.setProperty("autoinstall_known_extensions", Boolean.toString(autoload));
            try (Connection c = DriverManager.getConnection("jdbc:duckdb:", p)) {
                Smoke.equal(EXPECTED, Smoke.scalar(c, Smoke.SETS));
                for (String key : p.stringPropertyNames()) {
                    if (key.startsWith("gcs_")) {
                        Smoke.equal(p.getProperty(key), Smoke.scalar(c, "SELECT current_setting('" + key + "')"));
                    }
                }
                try (Statement s = c.createStatement()) { s.execute(conflict(args[1])); }
                for (String scheme : new String[] {"gs", "gcs", "gcss"}) {
                    Smoke.equal("42", Smoke.scalar(c, "SELECT sum(i) FROM read_csv('" + scheme + "://fixture/values.csv')"));
                    try (PreparedStatement s = c.prepareStatement("SELECT count(*) || ':' || sum(i) FROM read_parquet(?)")) {
                        s.setString(1, scheme + "://fixture/data.parquet");
                        try (ResultSet r = s.executeQuery()) {
                            if (!r.next()) throw new AssertionError("Missing GCS Parquet result");
                            Smoke.equal("10000:49995000", r.getString(1));
                        }
                    }
                }
                // HTTPFS must still handle normal HTTP alongside the native GCS provider.
                Smoke.equal("42", Smoke.scalar(c, "SELECT sum(i) FROM read_csv('" + args[0] + "/values.csv')"));
                try (Statement s = c.createStatement()) {
                    s.execute("SET gcs_max_metadata_cache_entries=19");
                    s.execute("SET enable_external_access=false");
                }
                Smoke.equal("19", Smoke.scalar(c, "SELECT current_setting('gcs_max_metadata_cache_entries')"));
                Smoke.rejects(c, "SELECT * FROM read_csv('gs://fixture/values.csv')", "disabled");
            }
        }
        // Mixed startup properties must preserve HTTPFS's existing lookup path.
        Properties mixed = options();
        mixed.setProperty("autoload_known_extensions", "true");
        mixed.setProperty("http_timeout", "5");
        try (Connection c = DriverManager.getConnection("jdbc:duckdb:", mixed); Statement s = c.createStatement()) {
            Smoke.equal("5", Smoke.scalar(c, "SELECT current_setting('http_timeout')"));
            Smoke.equal("17", Smoke.scalar(c, "SELECT current_setting('gcs_max_metadata_cache_entries')"));
            s.execute(conflict(args[1]));
            Smoke.equal("42", Smoke.scalar(c, "SELECT sum(i) FROM read_csv('gs://fixture/values.csv')"));
            Smoke.equal("42", Smoke.scalar(c, "SELECT sum(i) FROM read_csv('" + args[0] + "/values.csv')"));
        }
        Properties bad = options();
        bad.setProperty("gcs_max_metadata_cache_entries", "-1");
        rejectOpen(bad, "convert");
        bad = options();
        bad.setProperty("gcs_enable_metadata_cache", "not-a-boolean");
        rejectOpen(bad, "convert");
        bad = options();
        bad.setProperty("gcs_not_an_option", "1");
        rejectOpen(bad, "not recognized");
        // An explicit GCP secret overrides valid ADC; an invalid token must not fall back to ADC.
        for (String token : new String[] {"explicit-token", "invalid-token"}) {
            try (Connection c = DriverManager.getConnection("jdbc:duckdb:", options()); Statement s = c.createStatement()) {
                s.execute(conflict(args[1]));
                s.execute("CREATE SECRET native_gcp (TYPE GCP, PROVIDER access_token, ACCESS_TOKEN '" + token + "')");
                if (token.equals("explicit-token")) {
                    Smoke.equal("42", Smoke.scalar(c, "SELECT sum(i) FROM read_csv('gs://fixture/values.csv')"));
                } else {
                    Smoke.rejects(c, "SELECT * FROM read_csv('gs://fixture/values.csv')", "denied");
                }
            }
        }
        System.out.println("PASS GCS JDBC startup options/types, ADC, explicit credentials, three schemes, HTTPFS coexistence");
    }
}
