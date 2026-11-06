import java.sql.*;
import java.util.Properties;

public final class CatalogSmoke {
    public static void main(String[] args) throws Exception {
        Properties p = new Properties();
        p.setProperty("autoload_known_extensions", "false");
        p.setProperty("autoinstall_known_extensions", "false");
        for (int i = 0; i < 2; i++) {
            try (Connection c = DriverManager.getConnection("jdbc:duckdb:", p)) {
                Smoke.equal(args[0], Smoke.scalar(c, Smoke.SETS));
                Smoke.equal("v2.0.0", Smoke.scalar(c, "SELECT version()"));
                try (Statement s = c.createStatement()) { s.execute(args[1]); }
                if (args[0].contains("odbc_scanner")) {
                    Smoke.rejects(c, "SELECT odbc_connect('Driver=Nonexistent;')", "enable_external_access");
                    Smoke.rejects(c, "SELECT * FROM odbc_query('Driver=Nonexistent;', 'SELECT 1')",
                                  "enable_external_access");
                }
            }
        }
        System.out.println("PASS " + args[0]);
    }
}
