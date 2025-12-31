# MySQL 8.4 + Java 21 SQL学習環境

MySQL 8.4 LTS と Java 21 の学習用Docker環境です。SQL学習用のサンプルテーブル（Shops, Address等）を含み、JDBC接続とEXPLAIN実行計画の確認ができます。

## ディレクトリ構成

```
db-practice/
├── docker-compose.yml
├── Makefile                     # db:restart等の便利コマンド
├── mysql/
│   ├── conf.d/
│   │   └── my.cnf              # MySQL設定（utf8mb4）
│   └── init/
│       └── 00-init.sql         # Shops, Address等のテーブル作成
├── sample-queries/              # 学習用サンプルクエリ（参照用）
│   ├── Code1.sql
│   ├── Code2.sql
│   └── ...
├── java-app/
│   ├── Dockerfile
│   ├── build.gradle
│   ├── settings.gradle
│   └── src/main/java/com/example/
│       └── App.java            # 接続テスト & EXPLAIN実行サンプル
└── README.md
```

## 起動方法

### 1. MySQL + Javaコンテナを起動

```bash
make db:start
# または
docker compose up -d
```

初回起動時、MySQLはサンプルテーブルを自動作成します（数秒で完了）。

### 2. DBリセット（ボリューム削除 → 再起動）

```bash
make db:restart
```

データを完全にリセットして初期状態に戻します。

## 動作確認

### MySQL接続確認（ホストから）

```bash
make db:connect
# または
mysql -h127.0.0.1 -uroot -proot sql_practice
```

```sql
SHOW TABLES;
SELECT * FROM Shops LIMIT 5;
SELECT * FROM Address;
```

### Javaアプリ実行（接続テスト）

```bash
docker compose run --rm java-app
```

実行内容:
1. MySQL接続確認
2. Shopsテーブルのクエリ
3. Shops + Reservations JOIN + EXPLAIN実行計画の表示

## データベース情報

### 接続情報

| 項目 | 値 |
|------|------|
| ホスト | localhost（ホストから）/ mysql（コンテナ間） |
| ポート | 3306 |
| ユーザー | root |
| パスワード | root |
| 文字コード | utf8mb4 |

### テーブル一覧（sql_practice）

| テーブル名 | 説明 |
|-----------|------|
| Shops | 店舗テーブル（60件） |
| Reservations | 予約管理テーブル（10件） |
| Address | 住所テーブル（9件） |
| Address2 | 住所テーブル2（6件） |

## Javaアプリのカスタマイズ

`java-app/src/main/java/com/example/App.java` を編集して、独自のクエリを試せます。

```bash
# 編集後、再実行
docker compose run --rm java-app
```

## データの永続化

MySQLデータは `mysql-data` Dockerボリュームに保存され、コンテナ再起動後も保持されます。

### データベースを初期化する場合

```bash
docker compose down -v  # ボリュームを削除
docker compose up -d    # 再度初期化
```

## コンテナ操作

```bash
# 起動
docker compose up -d

# 停止
docker compose down

# MySQL ログ確認
docker compose logs mysql

# MySQL コンテナに入る
docker compose exec mysql bash

# Javaアプリをワンショット実行
docker compose run --rm java-app

# すべて削除（ボリューム含む）
docker compose down -v
```

## 学習リソース

### サンプルクエリ
`sample-queries/` ディレクトリに学習用のSQLサンプルがあります：
- Code1.sql: テーブルスキャン、インデックス、結合
- Code2.sql: SELECT、WHERE、GROUP BY、集計関数
- Code3.sql以降: 高度なクエリ（サブクエリ、ウィンドウ関数等）

### 実行方法
```bash
# MySQL CLIで直接実行
mysql -h127.0.0.1 -uroot -proot sql_practice < sample-queries/Code1.sql

# または対話的に実行
mysql -h127.0.0.1 -uroot -proot sql_practice
mysql> source sample-queries/Code2.sql;
```

## トラブルシューティング

### ポート3306がすでに使用されている

```bash
# ホストのMySQLを停止
sudo service mysql stop  # Linux
brew services stop mysql # macOS

# または docker-compose.yml のポートを変更
ports:
  - "3307:3306"  # ホスト側を3307に変更
```

### Java接続エラー

MySQLが完全に起動するまで待つ必要があります:

```bash
docker compose logs mysql | grep "ready for connections"
```

### 初期化スクリプトが実行されない

ボリュームが残っている場合、初期化スクリプトは再実行されません:

```bash
docker compose down -v
docker compose up -d
```

## ライセンス

学習用途のため、ご自由にお使いください。
# sql-practice
