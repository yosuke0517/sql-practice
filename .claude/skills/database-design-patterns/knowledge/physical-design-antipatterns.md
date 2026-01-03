# 物理設計アンチパターン集

## 31 Flavors（サーティワンフレーバー）

### 概要
ENUMやCHECK制約で値を制限するアンチパターン。値の追加にALTER TABLEが必要で、メタデータ（スキーマ）とデータが混在する。

### 問題のパターン

```sql
-- ❌ 悪い例: ENUM で値を制限
CREATE TABLE Bugs (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    status ENUM('new', 'in_progress', 'resolved', 'closed')  -- 固定値
);

INSERT INTO Bugs VALUES (1, 'Login fails', 'new');
```

**問題点:**

#### 1. 値追加にALTER TABLEが必要
```sql
-- 新しいステータス 'reopened' を追加したい
ALTER TABLE Bugs
MODIFY status ENUM('new', 'in_progress', 'resolved', 'closed', 'reopened');

-- スキーマ変更が必要（ダウンタイム、ロック）
```

#### 2. 値の一覧取得が困難
```sql
-- status の取りうる値を取得したい
SHOW COLUMNS FROM Bugs LIKE 'status';
-- → メタデータからパース必要（アプリケーション側で処理）

-- 標準SQLでは取得不可能
```

#### 3. 値の順序が不定
```sql
-- ENUM は内部的に数値として格納
-- ソート順序が定義順になる（アルファベット順ではない）

SELECT * FROM Bugs ORDER BY status;
-- → 'closed', 'in_progress', 'new', 'resolved' （定義順）
```

#### 4. ポータビリティが低い
```sql
-- ENUM は MySQL固有
-- PostgreSQL では CHECK制約または独自型
-- SQL Server では CHECK制約

-- 移植が困難
```

#### 5. 値の変更が困難
```sql
-- 'in_progress' を 'in-progress' に変更したい
-- → 全行のデータ変更 + スキーマ変更が必要

UPDATE Bugs SET status = 'in-progress' WHERE status = 'in_progress';
ALTER TABLE Bugs
MODIFY status ENUM('new', 'in-progress', 'resolved', 'closed');
```

### 解決策: 参照テーブル（ルックアップテーブル）

```sql
-- ✅ 良い例: 参照テーブル
CREATE TABLE BugStatus (
    status_id INT PRIMARY KEY,
    status_name VARCHAR(20) UNIQUE NOT NULL,
    sort_order INT NOT NULL
);

CREATE TABLE Bugs (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    status_id INT NOT NULL,
    FOREIGN KEY (status_id) REFERENCES BugStatus(status_id)
);

-- ステータスマスタ挿入
INSERT INTO BugStatus VALUES
(1, 'new', 1),
(2, 'in_progress', 2),
(3, 'resolved', 3),
(4, 'closed', 4);

-- バグ挿入
INSERT INTO Bugs VALUES (1, 'Login fails', 1);  -- status_id=1 (new)
```

**メリット:**

#### 1. 値追加はINSERTのみ
```sql
-- 新しいステータス 'reopened' を追加
INSERT INTO BugStatus VALUES (5, 'reopened', 5);

-- スキーマ変更不要
```

#### 2. 値の一覧取得が簡単
```sql
-- status の取りうる値を取得
SELECT * FROM BugStatus ORDER BY sort_order;
```

#### 3. 値の順序を制御可能
```sql
-- sort_order でソート順序を定義
SELECT b.*, bs.status_name
FROM Bugs b
JOIN BugStatus bs ON b.status_id = bs.status_id
ORDER BY bs.sort_order;
```

#### 4. ポータビリティが高い
```sql
-- 標準SQL（すべてのRDBMSで動作）
```

#### 5. 値の変更が簡単
```sql
-- 'in_progress' を 'in-progress' に変更
UPDATE BugStatus SET status_name = 'in-progress' WHERE status_id = 2;

-- スキーマ変更不要
```

#### 6. 追加情報を格納可能
```sql
-- 色、アイコン、説明などを追加
ALTER TABLE BugStatus
ADD COLUMN color VARCHAR(7),  -- '#ff0000'
ADD COLUMN description TEXT;

UPDATE BugStatus SET color = '#ff0000', description = 'New bug report' WHERE status_id = 1;
```

### ENUMが許容されるケース

#### ケース1: 絶対に変わらない値
```sql
-- 性別（male/female/other）など、追加される可能性が極めて低い
CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    gender ENUM('male', 'female', 'other')
);
```

**注意:** それでも参照テーブルの方が柔軟性が高い

#### ケース2: アプリケーション側で厳密に管理
```sql
-- ORM（Ruby on Rails等）で enum を管理している場合
-- ただし、DBとアプリケーションの二重管理になる
```

### 検出方法

#### チェックポイント
- [ ] **ENUM型を使っているか？**
  ```sql
  SHOW COLUMNS FROM table_name;
  -- Type が 'enum(...)' になっている
  ```

- [ ] **CHECK制約で値を制限しているか？**
  ```sql
  -- PostgreSQL / SQL Server
  CHECK (status IN ('new', 'in_progress', 'resolved'))
  ```

- [ ] **値の追加が予想されるか？**
  - ステータス、カテゴリ、タイプなど

---

## Rounding Errors（丸め誤差）

### 概要
FLOAT/DOUBLEで金額や重要な数値を格納するアンチパターン。浮動小数点の誤差が蓄積し、正確な計算ができない。

### 問題のパターン

```sql
-- ❌ 悪い例: FLOAT で金額を格納
CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    total_price FLOAT  -- 浮動小数点
);

INSERT INTO Orders VALUES (1, 999.99);

-- 誤差が発生
SELECT total_price FROM Orders WHERE order_id = 1;
-- → 999.9899902343750 （期待: 999.99）
```

**問題点:**

#### 1. 浮動小数点の誤差
```sql
-- 0.1 + 0.2 の計算
SELECT 0.1 + 0.2;
-- → 0.30000000000000004 （期待: 0.3）

-- 金額計算で致命的
SELECT CAST(0.1 AS FLOAT) + CAST(0.2 AS FLOAT);
-- → 0.30000001192092896
```

#### 2. 誤差の蓄積
```sql
-- 大量の加算で誤差が蓄積
SELECT SUM(price) FROM OrderItems WHERE order_id = 1;
-- → 999.9899902... （期待: 1000.00）
```

#### 3. 等価比較が不正確
```sql
-- 999.99 の注文を検索
SELECT * FROM Orders WHERE total_price = 999.99;
-- → ヒットしない（内部的には 999.9899902...）

-- BETWEEN で範囲指定が必要
SELECT * FROM Orders WHERE total_price BETWEEN 999.98 AND 1000.00;
```

#### 4. 税計算・消費税で問題
```sql
-- 消費税10%の計算
SELECT price * 1.1 FROM Products WHERE product_id = 1;
-- → 109.89999961853027 （期待: 109.90）

-- 四捨五入しても誤差が残る
SELECT ROUND(price * 1.1, 2) FROM Products;
-- → 109.90 （一見正しいが、内部的には誤差あり）
```

### 解決策: DECIMAL/NUMERIC型を使う

```sql
-- ✅ 良い例: DECIMAL で金額を格納
CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    total_price DECIMAL(10, 2)  -- 整数部8桁 + 小数部2桁
);

INSERT INTO Orders VALUES (1, 999.99);

-- 正確な値
SELECT total_price FROM Orders WHERE order_id = 1;
-- → 999.99 （正確）
```

**DECIMAL の仕様:**
```sql
DECIMAL(precision, scale)

precision: 全体の桁数（整数部 + 小数部）
scale:     小数部の桁数

例:
DECIMAL(10, 2) → 最大 99999999.99 （整数部8桁 + 小数部2桁）
DECIMAL(15, 4) → 最大 99999999999.9999 （整数部11桁 + 小数部4桁）
```

**正確な計算:**
```sql
-- 加算
SELECT CAST(0.1 AS DECIMAL(10,2)) + CAST(0.2 AS DECIMAL(10,2));
-- → 0.30 （正確）

-- 消費税計算
SELECT price * 1.1 FROM Products;
-- → 109.90 （正確）

-- 集計
SELECT SUM(total_price) FROM Orders;
-- → 正確な合計値
```

**等価比較:**
```sql
-- 正確な等価比較
SELECT * FROM Orders WHERE total_price = 999.99;
-- → ヒットする
```

### DECIMAL のサイズ選択

| 用途 | DECIMAL | 範囲 |
|---|---|---|
| 一般的な金額（円・ドル） | DECIMAL(10, 2) | 〜99,999,999.99 |
| 大きい金額（億単位） | DECIMAL(15, 2) | 〜9,999,999,999,999.99 |
| 仮想通貨（8桁精度） | DECIMAL(20, 8) | 〜999,999,999,999.99999999 |
| 為替レート | DECIMAL(10, 4) | 〜999,999.9999 |

### FLOAT/DOUBLEが許容されるケース

#### ケース1: 科学計算・近似値
```sql
-- 温度、距離、重量など（完全な精度が不要）
CREATE TABLE Measurements (
    measurement_id INT PRIMARY KEY,
    temperature FLOAT,  -- 23.456789... （誤差許容）
    distance DOUBLE     -- 12345.6789... （誤差許容）
);
```

#### ケース2: 極めて大きい・小さい数値
```sql
-- 指数表記が必要な数値
-- 例: 1.23e+100, 4.56e-50
```

**注意:** それでも金額・数量には使わない

### 検出方法

#### チェックポイント
- [ ] **FLOAT/DOUBLEで金額を格納しているか？**
  ```sql
  SHOW COLUMNS FROM table_name;
  -- Type が 'float' または 'double' の列
  ```

- [ ] **列名に price, amount, balance が含まれるか？**
  - 金額を示す列名

- [ ] **消費税・税率計算をしているか？**
  - 浮動小数点での計算は誤差が蓄積

---

## Phantom Files（ファントムファイル）

### 概要
ファイルパスのみDBに格納するアンチパターン。ファイルとDBの整合性が取れず、トランザクションで保護できない。

### 問題のパターン

```sql
-- ❌ 悪い例: ファイルパスのみ格納
CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    username VARCHAR(255),
    avatar_path VARCHAR(500)  -- '/uploads/avatars/user123.jpg'
);

INSERT INTO Users VALUES (1, 'alice', '/uploads/avatars/alice.jpg');
```

**問題点:**

#### 1. ファイルとDBの整合性が取れない
```sql
-- ユーザー削除
DELETE FROM Users WHERE user_id = 1;
-- → DBからは削除されるが、ファイルは残る（孤立ファイル）

-- ファイル削除
-- アプリケーション側で DELETE 後に unlink('/uploads/avatars/alice.jpg')
-- → 削除失敗してもロールバック不可
```

#### 2. トランザクションで保護できない
```sql
BEGIN;
    INSERT INTO Users VALUES (2, 'bob', '/uploads/avatars/bob.jpg');
    -- ファイルをアップロード（アプリケーション側）
    -- → エラー発生
ROLLBACK;
-- → DBはロールバックされるが、ファイルは残る
```

#### 3. バックアップ・リストアが困難
```sql
-- DBバックアップ
mysqldump db > backup.sql

-- ファイルシステムのバックアップが別途必要
tar -czf uploads.tar.gz /uploads/

-- リストア時にタイミングがずれると整合性が壊れる
```

#### 4. ファイル削除検証が困難
```sql
-- パスが正しいか検証できない（DBではファイルの存在確認不可）
SELECT * FROM Users WHERE avatar_path IS NOT NULL;
-- → パスは存在するが、ファイルが存在しない可能性
```

#### 5. パーミッション・セキュリティ問題
```sql
-- ファイルパスが推測可能
-- '/uploads/avatars/user1.jpg', '/uploads/avatars/user2.jpg'
-- → 直接アクセスされる可能性
```

### 解決策

#### 方法1: BLOBで格納（小さいファイル）
```sql
-- ✅ 良い例: BLOB で格納
CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    username VARCHAR(255),
    avatar_image BLOB,       -- バイナリデータ
    avatar_mime_type VARCHAR(50),
    avatar_size INT
);

-- ファイル挿入
INSERT INTO Users (user_id, username, avatar_image, avatar_mime_type, avatar_size)
VALUES (1, 'alice', LOAD_FILE('/tmp/alice.jpg'), 'image/jpeg', 12345);

-- ファイル取得（アプリケーション側）
SELECT avatar_image, avatar_mime_type FROM Users WHERE user_id = 1;
```

**メリット:**
- トランザクションで保護
- バックアップ・リストアが簡単
- 整合性が保証される
- セキュリティ向上（直接アクセス不可）

**デメリット:**
- DBサイズが大きくなる
- パフォーマンス低下（大きいファイル）

**適用ケース:**
- 小さいファイル（〜1MB: アバター画像、サムネイル）
- トランザクション保護が重要

#### 方法2: 外部ストレージ + メタデータ管理（大きいファイル）
```sql
-- ✅ 良い例: S3 + メタデータ
CREATE TABLE Users (
    user_id INT PRIMARY KEY,
    username VARCHAR(255),
    avatar_s3_key VARCHAR(500),  -- 'avatars/user-1-20240101.jpg'
    avatar_mime_type VARCHAR(50),
    avatar_size INT,
    avatar_uploaded_at TIMESTAMP
);

-- アプリケーション側でS3にアップロード
-- s3.put_object(Bucket='my-bucket', Key='avatars/user-1-20240101.jpg', Body=file_data)

-- DBにメタデータ挿入
INSERT INTO Users (user_id, username, avatar_s3_key, avatar_uploaded_at)
VALUES (1, 'alice', 'avatars/user-1-20240101.jpg', NOW());

-- ファイル取得（アプリケーション側）
-- s3.get_object(Bucket='my-bucket', Key=avatar_s3_key)
```

**メリット:**
- 大きいファイルに対応（動画、高解像度画像）
- DBサイズを抑える
- CDN連携でパフォーマンス向上
- スケーラビリティ

**注意点:**
- トランザクション保護は不完全（S3とDBの整合性）
- アプリケーション側で整合性管理が必要

**整合性管理:**
```python
# アプリケーション側での整合性管理例（Python）
try:
    # S3にアップロード
    s3.put_object(Bucket='my-bucket', Key=s3_key, Body=file_data)

    # DBに挿入
    db.execute("INSERT INTO Users ...")
    db.commit()
except Exception as e:
    # ロールバック + S3削除
    db.rollback()
    s3.delete_object(Bucket='my-bucket', Key=s3_key)
    raise
```

#### 方法3: トランザクション対応のファイル管理
```sql
-- ファイルシステムにトランザクション機能を追加
-- 例: ZFS, Btrfs のスナップショット機能

-- または、アプリケーション側でトランザクションログ管理
```

### 適用ガイドライン

| ファイルサイズ | 推奨方法 |
|---|---|
| 〜1MB | BLOB（トランザクション保護） |
| 1MB〜10MB | 外部ストレージ + メタデータ（要整合性管理） |
| 10MB〜 | 外部ストレージ + メタデータ（CDN推奨） |

### 検出方法

#### チェックポイント
- [ ] **ファイルパスを格納する列があるか？**
  - 列名: `*_path`, `*_url`, `*_file`
  - 値: `/uploads/...`, `https://...`

- [ ] **ファイル削除処理がトランザクション外か？**
  - アプリケーションログを確認

- [ ] **孤立ファイルが存在するか？**
  - ファイルシステムとDBの比較

---

## まとめ

### 物理設計アンチパターン早見表

| アンチパターン | 問題 | 解決策 |
|---|---|---|
| **31 Flavors** | ENUM/CHECK で値制限 | 参照テーブル + 外部キー |
| **Rounding Errors** | FLOAT/DOUBLE で金額 | DECIMAL/NUMERIC |
| **Phantom Files** | ファイルパスのみ | BLOB、または外部ストレージ + メタデータ |

### 共通の教訓

1. **メタデータとデータを分離**: ENUMより参照テーブル
2. **精度が必要な数値はDECIMAL**: 金額、数量、税率
3. **ファイルとDBの整合性を保つ**: BLOB、またはトランザクション対応の外部ストレージ
4. **拡張性を考慮**: 値の追加・変更が簡単な設計

---

## 参考資料

- O'Reilly「SQLアンチパターン」(oreilly-978-4-8144-0074-4e)
