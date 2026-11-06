import java.sql.*;
import java.util.Properties;

// Acceptance probe for the installed CLI/JDBC extension compositions.
public final class Smoke {
    static final String SETS = "SELECT string_agg(extension_name, ',' ORDER BY extension_name) "
        + "FROM duckdb_extensions() WHERE loaded AND extension_name <> 'shell'";
    static final String ICU = "SELECT epoch(timezone('Europe/Amsterdam', TIMESTAMP '2026-01-15 12:00:00')) "
        + "= epoch(TIMESTAMPTZ '2026-01-15 11:00:00+00')";

    static String scalar(Connection c, String sql) throws SQLException {
        try (Statement s = c.createStatement(); ResultSet r = s.executeQuery(sql)) {
            if (!r.next()) throw new AssertionError("No row: " + sql);
            return r.getString(1);
        }
    }
    static void equal(String expected, String actual) {
        if (!expected.equals(actual)) throw new AssertionError(expected + " != " + actual);
    }
    static void rejects(Connection c, String sql, String expectedMessage) throws SQLException {
        try (Statement s = c.createStatement()) {
            s.execute(sql);
        } catch (SQLException e) {
            if (!e.getMessage().toLowerCase().contains(expectedMessage)) throw e;
            return;
        }
        throw new AssertionError("Unexpected success: " + sql);
    }
    public static void main(String[] args) throws Exception {
        String expected = args[0];
        boolean hasIcu = expected.contains("icu");
        Properties p = new Properties();
        p.setProperty("autoload_known_extensions", "false");
        p.setProperty("autoinstall_known_extensions", "false");
        // DriverManager discovers the driver from META-INF/services.
        // Repeat after closing the preceding database: registration must survive.
        for (int i = 0; i < 3; i++) {
            try (Connection c = DriverManager.getConnection("jdbc:duckdb:", p)) {
                equal(expected, scalar(c, SETS)); // inspect before invoking any extension function
                equal("v2.0.0", scalar(c, "SELECT version()"));
                equal("42", scalar(c, "SELECT 6 * 7"));
                try (PreparedStatement s = c.prepareStatement("SELECT json_extract_string(?::JSON, '$.v')")) {
                    s.setString(1, "{\"v\":\"works-λ\"}");
                    try (ResultSet r = s.executeQuery()) {
                        if (!r.next()) throw new AssertionError("Missing JSON result");
                        equal("works-λ", r.getString(1));
                    }
                }
                try (Statement s = c.createStatement()) { s.execute("LOAD json; LOAD json"); }
                if (hasIcu) equal("true", scalar(c, ICU));
                else {
                    rejects(c, ICU, "icu");
                    rejects(c, "LOAD icu", "does not link the loadable_extensions library");
                }
                String omitted = expected.contains("parquet") ? "tpch" : "parquet";
                rejects(c, "LOAD " + omitted, "does not link the loadable_extensions library");
                rejects(c, "INSTALL " + omitted, "does not link the loadable_extensions library");
                equal(expected, scalar(c, SETS));
            }
        }
        System.out.println("PASS JDBC " + expected + ": 3 databases, prepared JSON, ICU inclusion/exclusion, LOAD/INSTALL");
    }
}
