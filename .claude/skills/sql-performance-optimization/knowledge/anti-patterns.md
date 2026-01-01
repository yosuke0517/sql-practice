# アンチパターン集

## 冗長性症候群（UNIONによる条件分岐）

### 概要
「WHERE句で条件分岐させるのは素人。プロはSELECT句で分岐させる」

UNIONを使った条件分岐は、同じテーブルを複数回スキャンするため非効率。CASE式を使うことで1回のスキャンで済む。

### 問題のパターン

#### パターン1: 条件による列の切り替え
```sql
-- ❌ UNIONで分岐（素人のやり方）
SELECT item_name, year, price_tax_ex AS price
FROM Items
WHERE year <= 2001
UNION ALL
SELECT item_name, year, price_tax_in AS price
FROM Items
WHERE year >= 2002;
```

**問題点:**
- テーブルを **2回スキャン**
- 実行計画が冗長
- I/Oコストが2倍

```
実行計画:
-> Append
   -> Table scan on Items  ← 1回目
   -> Table scan on Items  ← 2回目
```

#### パターン2: 集計における条件分岐
```sql
-- ❌ UNIONで分岐
SELECT prefecture, SUM(pop_men), SUM(pop_wom)
FROM (
    SELECT prefecture, pop AS pop_men, NULL AS pop_wom
    FROM Population WHERE sex = '1'
    UNION
    SELECT prefecture, NULL, pop AS pop_wom
    FROM Population WHERE sex = '2'
) tmp
GROUP BY prefecture;
```

**問題点:**
- テーブル2回スキャン
- サブクエリが複雑化
- メンテナンス性低下

### 解決策：CASE式を使う

#### パターン1の解決
```sql
-- ✅ CASE式で分岐（プロのやり方）
SELECT item_name, year,
       CASE WHEN year <= 2001 THEN price_tax_ex
            WHEN year >= 2002 THEN price_tax_in
       END AS price
FROM Items;
```

**メリット:**
- テーブルを **1回スキャン**
- 実行計画がシンプル
- I/Oコストが半分

```
実行計画:
-> Table scan on Items  ← 1回だけ！
```

#### パターン2の解決
```sql
-- ✅ CASE式で分岐
SELECT prefecture,
       SUM(CASE WHEN sex = '1' THEN pop ELSE 0 END) AS pop_men,
       SUM(CASE WHEN sex = '2' THEN pop ELSE 0 END) AS pop_wom
FROM Population
GROUP BY prefecture;
```

**メリット:**
- テーブル1回スキャン
- シンプルで読みやすい
- パフォーマンス向上

---

## UNIONを使うべき例外ケース

### 1. 異なるテーブルをマージする場合
```sql
SELECT col_1 FROM Table_A WHERE col_2 = 'A'
UNION ALL
SELECT col_3 FROM Table_B WHERE col_4 = 'B';
```
→ これはCASE式では代替できない

### 2. インデックスが効く場合
```sql
-- 各列にインデックスがある場合
SELECT * FROM ThreeElements WHERE date_1 = '2013-11-01' AND flg_1 = 'T'
UNION
SELECT * FROM ThreeElements WHERE date_2 = '2013-11-01' AND flg_2 = 'T'
UNION
SELECT * FROM ThreeElements WHERE date_3 = '2013-11-01' AND flg_3 = 'T';
```

**比較:**
- UNION: 3回のインデックススキャン
- OR/CASE: 1回のフルテーブルスキャン

→ テーブルが大きく、選択率が低い場合はUNIONが勝つこともある

---

## 判断フロー

```
条件分岐が必要？
  ├─ 同じテーブル？
  │    ├─ Yes → CASE式を使う
  │    └─ No（異なるテーブル）→ UNIONを使う
  │
  └─ インデックスが効く？
       ├─ Yes + 選択率低い → UNIONも検討
       └─ No → CASE式を使う
```

---

## パラダイムシフト

```
手続き型思考（文ベース）     宣言型思考（式ベース）
    IF文 / SWITCH文     →     CASE式
    複数のSELECT文      →     1つのSELECT文
    UNION              →     CASE式
```

---

## ぐるぐる系（N+1問題）

### 概要
「ぐるぐる系」はSQLの本領を発揮できない。「ガツン系」で集合を一括処理せよ

**用語整理:**
- **ぐるぐる系**: 1行ずつSQLを発行してループ（= N+1問題）
- **ガツン系**: 1回のSQLで複数行を一括処理

### 問題のパターン

#### ぐるぐる系の典型例
```java
// アプリ側でループ
for (row : salesData) {
    // 1行ずつSELECT
    result = SELECT * FROM Sales WHERE id = ?;
    // 1行ずつINSERT
    INSERT INTO Sales2 VALUES (...);
}
```

**問題点:**
- SQL発行のオーバーヘッド × N回
- ネットワークラウンドトリップ × N回
- 並列処理しにくい
- DBMSの最適化の恩恵を受けられない
- トランザクションログが肥大化

**パフォーマンス:**
```
N=1000の場合:
ぐるぐる系: 10秒
ガツン系:   0.1秒
→ 100倍の差
```

### 解決策：ガツン系に書き換え

#### パターン1: ウィンドウ関数で一括処理
```sql
-- ❌ ぐるぐる系
-- アプリ側で前年比を計算
for (company : companies) {
    prevYear = SELECT sale FROM Sales WHERE company = ? AND year = ? - 1;
    thisYear = SELECT sale FROM Sales WHERE company = ? AND year = ?;
    var = thisYear - prevYear;
    INSERT INTO Sales2 VALUES (company, year, thisYear, var);
}

-- ✅ ガツン系（LAG関数）
INSERT INTO Sales2
SELECT company, year, sale,
       CASE SIGN(sale - LAG(sale) OVER (PARTITION BY company ORDER BY year))
            WHEN 1  THEN '+'
            WHEN -1 THEN '-'
            WHEN 0  THEN '='
       END AS var
FROM Sales;
```

**メリット:**
- 1回のSQLで全件処理
- DBMSの並列処理が効く
- 実行計画の最適化が効く

#### パターン2: JOINで一括処理
```sql
-- ❌ ぐるぐる系
for (user : users) {
    orders = SELECT * FROM Orders WHERE user_id = ?;
    // 処理...
}

-- ✅ ガツン系（JOIN）
SELECT u.*, o.*
FROM Users u
LEFT JOIN Orders o ON u.id = o.user_id;
```

#### パターン3: IN句で一括処理
```sql
-- ❌ ぐるぐる系
for (id : ids) {
    SELECT * FROM Products WHERE id = ?;
}

-- ✅ ガツン系（IN句）
SELECT * FROM Products WHERE id IN (?, ?, ?);
```

#### パターン4: 一括INSERT
```sql
-- ❌ ぐるぐる系
for (row : data) {
    INSERT INTO Products VALUES (?, ?, ?);
}

-- ✅ ガツン系（一括INSERT）
INSERT INTO Products VALUES
    (1, 'A', 100),
    (2, 'B', 200),
    (3, 'C', 300);

-- または（推奨）
INSERT INTO Products
SELECT * FROM staging_table;
```

---

## ぐるぐる系 vs ガツン系

| 観点 | ぐるぐる系 | ガツン系 |
|------|-----------|---------|
| **パフォーマンス** | ❌ 遅い（線形に悪化） | ✅ 速い |
| **スケーラビリティ** | ❌ データ量に比例して劣化 | ✅ 最適化が効く |
| **チューニング余地** | ❌ ほぼない | ✅ あり（インデックス、実行計画等） |
| **実行計画の安定性** | ✅ 安定 | ⚠️ 変動リスク |
| **トランザクション制御** | ✅ 細かく可能 | ❌ 一括 |
| **見積り精度** | ✅ 比較的高い | ⚠️ 難しい |
| **エラーハンドリング** | ✅ 細かく可能 | ❌ 一括ロールバック |

---

## ぐるぐる系が許容されるケース

### 1. データ量が少ない
```sql
-- 数百行程度のオンライン処理
-- SQL発行のオーバーヘッドが問題にならない
```

### 2. トランザクション粒度を細かく制御したい
```java
for (order : orders) {
    try {
        // 1件ずつコミット
        processOrder(order);
        commit();
    } catch (Exception e) {
        rollback();
        // 他の注文は続行
    }
}
```

### 3. リスタート処理が必要なバッチ
```java
// 1000万件のバッチ処理
// 途中で失敗しても、処理済みの分は保持したい
for (batch : batches) {
    processBatch(batch);
    commit();
    saveCheckpoint(batch.id);  // リスタート用
}
```

### 4. 外部APIとの連携
```java
// 各行でAPIを呼ぶ必要がある
for (user : users) {
    result = callExternalAPI(user.id);
    UPDATE users SET status = ? WHERE id = user.id;
}
```

---

## SQLでループを代用する武器

| 道具 | 役割 | 例 |
|------|------|------|
| **CASE式** | IF-THEN-ELSE | 条件分岐 |
| **ウィンドウ関数** | ループ（前後の行参照） | LAG, LEAD, ROW_NUMBER |
| **再帰CTE** | 階層データの走査 | 組織図、カテゴリツリー |
| **集約関数** | グループごとの計算 | SUM, COUNT, AVG |

**重要:** CASE式とウィンドウ関数はセットで覚える！

---

## 検出方法

### アプリケーションログ
```
# 同じようなSQLが大量に発行されている
SELECT * FROM products WHERE id = 1;
SELECT * FROM products WHERE id = 2;
SELECT * FROM products WHERE id = 3;
...
```

### パフォーマンスプロファイラ
```
# クエリ実行回数が異常に多い
Query: SELECT * FROM products WHERE id = ?
Executions: 10,000
Total time: 120s
```

### ORMのN+1問題検出ツール
- **Rails**: Bullet gem
- **Django**: django-silk
- **JPA**: Hibernate Statistics

---

## 判断フロー

```
ループでSQL発行している？
  ├─ Yes → データ量は？
  │        ├─ 少ない（<100件） → 許容される場合も
  │        └─ 多い（>=100件） → ガツン系に書き換え
  │
  └─ No → OK
```

---

## まとめ

```
ぐるぐる系の正体:
  手続き型の「1行ずつ処理」をSQLに持ち込んだもの
  → SQLの集合指向と相性が悪い
  → パフォーマンスで勝てない

解決策:
  CASE式 + ウィンドウ関数でガツン系に書き換え
  → 1回のSQLで一括処理
  → DBMSの最適化が効く
```

**パラダイムシフト:**
```
手続き型思考                宣言型思考
  FOR文でループ       →     ウィンドウ関数
  1行ずつSELECT       →     JOIN/IN句で一括
  1行ずつINSERT       →     一括INSERT
```

**参照:**
- [knowledge/window-functions.md](./window-functions.md) - LAG/LEAD/ROW_NUMBERでループ代替
- [tasks/review-query.md](../tasks/review-query.md) - ぐるぐる系チェックポイント
