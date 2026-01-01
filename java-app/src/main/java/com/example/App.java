package com.example;

import java.sql.*;

public class App {
    private static final String DB_HOST = System.getenv().getOrDefault("DB_HOST", "localhost");
    private static final String DB_PORT = System.getenv().getOrDefault("DB_PORT", "3306");
    private static final String DB_NAME = System.getenv().getOrDefault("DB_NAME", "sql_practice");
    private static final String DB_USER = System.getenv().getOrDefault("DB_USER", "root");
    private static final String DB_PASSWORD = System.getenv().getOrDefault("DB_PASSWORD", "root");

    private static final String JDBC_URL = String.format(
        "jdbc:mysql://%s:%s/%s?useSSL=false&allowPublicKeyRetrieval=true",
        DB_HOST, DB_PORT, DB_NAME
    );

    public static void main(String[] args) {
        System.out.println("=== MySQL Connection Test ===");
        System.out.println("JDBC URL: " + JDBC_URL);
        System.out.println();

        try (Connection conn = DriverManager.getConnection(JDBC_URL, DB_USER, DB_PASSWORD)) {
            System.out.println("✓ MySQL接続成功！");
            System.out.println("  Database: " + conn.getCatalog());
            System.out.println("  Version: " + conn.getMetaData().getDatabaseProductVersion());
            System.out.println();

            // Test 1: List available databases
            System.out.println("=== 利用可能なデータベース ===");
            listDatabases(conn);
            System.out.println();

            // Test 2: Query Shops table
            System.out.println("=== Shops テーブルクエリ ===");
            queryShops(conn);
            System.out.println();

            // Test 3: EXPLAIN query (execution plan)
            System.out.println("=== EXPLAIN: 実行計画の確認 ===");
            explainQuery(conn);

        } catch (SQLException e) {
            System.err.println("✗ データベース接続エラー:");
            System.err.println("  " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void listDatabases(Connection conn) throws SQLException {
        String query = "SHOW DATABASES";
        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {
            while (rs.next()) {
                System.out.println("  - " + rs.getString(1));
            }
        }
    }

    private static void queryShops(Connection conn) throws SQLException {
        String query = "SELECT shop_id, shop_name, rating, area FROM Shops LIMIT 10";

        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(query)) {

            System.out.printf("%-10s %-20s %-8s %-15s%n", "shop_id", "shop_name", "rating", "area");
            System.out.println("-".repeat(60));

            while (rs.next()) {
                System.out.printf("%-10s %-20s %-8d %-15s%n",
                    rs.getString("shop_id"),
                    rs.getString("shop_name"),
                    rs.getInt("rating"),
                    rs.getString("area")
                );
            }
        }
    }

    private static void explainQuery(Connection conn) throws SQLException {
        String explainQuery = "EXPLAIN SELECT S.shop_name, R.reserve_name " +
                              "FROM Shops S " +
                              "INNER JOIN Reservations R ON S.shop_id = R.shop_id " +
                              "WHERE S.area = '東京都'";

        System.out.println("クエリ:");
        System.out.println(explainQuery.replace("EXPLAIN ", ""));
        System.out.println();
        System.out.println("実行計画:");

        try (Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery(explainQuery)) {

            ResultSetMetaData metaData = rs.getMetaData();
            int columnCount = metaData.getColumnCount();

            // Print header
            for (int i = 1; i <= columnCount; i++) {
                System.out.printf("%-15s ", metaData.getColumnName(i));
            }
            System.out.println();
            System.out.println("-".repeat(15 * columnCount));

            // Print rows
            while (rs.next()) {
                for (int i = 1; i <= columnCount; i++) {
                    String value = rs.getString(i);
                    System.out.printf("%-15s ", value != null ? value : "NULL");
                }
                System.out.println();
            }
        }

        System.out.println();
        System.out.println("ポイント:");
        System.out.println("  - type: アクセスタイプ（ALL=フルスキャン, ref=インデックス利用など）");
        System.out.println("  - key: 使用されたインデックス");
        System.out.println("  - rows: 検査される推定行数");
    }
}
