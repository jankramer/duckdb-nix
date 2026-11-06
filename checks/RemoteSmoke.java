import java.sql.*;
import java.util.Properties;

public final class RemoteSmoke {
    public static void main(String[] args) throws Exception {
        Properties p = new Properties();
        // Startup option resolution loads the statically registered extension by name.
        p.setProperty("autoload_known_extensions", "true");
        p.setProperty("autoinstall_known_extensions", "false");
        // Extension options must be accepted during database creation.
        p.setProperty("http_timeout", "5");
        p.setProperty("http_retries", "0");
        p.setProperty("ca_cert_file", args[2]);
        p.setProperty("enable_server_cert_verification", "true");
        Properties disabledAutoload = (Properties) p.clone();
        disabledAutoload.setProperty("autoload_known_extensions", "false");
        try (Connection ignored = DriverManager.getConnection("jdbc:duckdb:", disabledAutoload)) {
            throw new AssertionError("Startup extension options unexpectedly bypassed disabled autoload");
        } catch (SQLException e) {
            if (!e.getMessage().contains("options were not recognized")) throw e;
        }
        Properties enabledInstall = (Properties) p.clone();
        enabledInstall.setProperty("autoinstall_known_extensions", "true");
        try (Connection ignored = DriverManager.getConnection("jdbc:duckdb:", enabledInstall)) {
            throw new AssertionError("Startup extension options unexpectedly bypassed auto-install");
        } catch (SQLException e) {
            if (!e.getMessage().contains("could not be autoloaded")) throw e;
        }
        for (String url : new String[] {args[0], args[1]}) {
            try (Connection c = DriverManager.getConnection("jdbc:duckdb:", p)) {
                Smoke.equal("core_functions,httpfs,icu,json,parquet", Smoke.scalar(c, Smoke.SETS));
                Smoke.equal("5", Smoke.scalar(c, "SELECT current_setting('http_timeout')"));
                Smoke.equal("42", Smoke.scalar(c, "SELECT sum(i) FROM read_csv('" + url + "/values.csv')"));
                try (PreparedStatement s = c.prepareStatement(
                        "SELECT count(*) || ':' || sum(i) FROM read_parquet(?) WHERE i % 2 = 0")) {
                    s.setString(1, url + "/data.parquet");
                    try (ResultSet r = s.executeQuery()) {
                        if (!r.next()) throw new AssertionError("Missing remote result");
                        Smoke.equal("5000:24995000", r.getString(1));
                    }
                }
                try (Statement s = c.createStatement()) {
                    s.execute("CREATE SECRET fixture_s3 (TYPE s3, KEY_ID 'test-only', SECRET 'test-only', REGION 'us-east-1')");
                }
                Smoke.equal("1", Smoke.scalar(c, "SELECT count(*) FROM duckdb_secrets() WHERE name='fixture_s3'"));
                try (Statement s = c.createStatement()) { s.execute("SET enable_external_access=false"); }
                Smoke.rejects(c, "SELECT * FROM read_csv('" + url + "/values.csv')", "disabled");
            }
        }
        p.setProperty("enable_external_access", "false");
        try (Connection c = DriverManager.getConnection("jdbc:duckdb:", p)) {
            Smoke.equal("42", Smoke.scalar(c, "SELECT 42"));
            Smoke.equal("5", Smoke.scalar(c, "SELECT current_setting('http_timeout')"));
            // duckdb_extensions() inspects disk as well as the in-memory registry.
            Smoke.rejects(c, Smoke.SETS, "disabled");
            Smoke.rejects(c, "SELECT * FROM read_csv('" + args[0] + "/values.csv')", "disabled");
        }
        System.out.println("PASS JDBC HTTP/HTTPS CSV + Parquet, startup settings, secrets, external-access restrictions");
    }
}
