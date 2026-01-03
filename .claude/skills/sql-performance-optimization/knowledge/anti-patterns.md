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

---

## 意図せぬクロス結合（三角結合）

> 「結合条件を1つでも忘れたら、直積（全行×全行）が発生する」

### 概要

**三角結合（Triangle JOIN）** とは、3つ以上のテーブルを結合する際に、一部のテーブルへの結合条件を忘れ、**意図せずクロス結合**が発生してしまうアンチパターン。

**問題の本質:**
- 結合条件が不足 → 孤立したテーブルが直積になる
- データが増えると性能が**指数関数的に悪化**
- `EXPLAIN` で検出可能だが、見落としやすい

### 問題のパターン

#### パターン1: 結合条件の書き忘れ

```sql
-- ❌ 悪い例: TableC への結合条件がない
SELECT *
FROM TableA A, TableB B, TableC C
WHERE A.id = B.id;
-- C が孤立 → (A JOIN B) × C の直積
```

**何が起きるか:**
```
TableA: 100行
TableB: 100行
TableC: 1,000行

A JOIN B = 100行（正常）
(A JOIN B) × C = 100 × 1,000 = 100,000行（異常）
```

#### パターン2: WHERE句での結合（カンマ結合）

```sql
-- ❌ 悪い例: WHERE句でのみ結合条件を記述
SELECT *
FROM Orders O, Customers C, Products P
WHERE O.customer_id = C.id
  AND O.product_id = P.id
  AND O.order_date >= '2024-01-01';  -- 条件が多いと見落としやすい
```

**問題:**
- 結合条件と検索条件が混在 → 可読性低下
- 条件を1つでも忘れると直積が発生

#### パターン3: サブクエリとの結合忘れ

```sql
-- ❌ 悪い例: サブクエリへの結合条件がない
SELECT *
FROM Orders O,
     (SELECT * FROM Products WHERE price > 1000) P
WHERE O.order_date >= '2024-01-01';
-- P が孤立 → O × P の直積
```

### 解決策：明示的にJOIN句を使う

#### ✅ 良い例1: JOIN句で結合条件を明示

```sql
SELECT *
FROM TableA A
JOIN TableB B ON A.id = B.id
JOIN TableC C ON B.id = C.id;  -- 全テーブルに結合条件
```

#### ✅ 良い例2: 複数カラムでの結合

```sql
SELECT *
FROM Orders O
JOIN Customers C ON O.customer_id = C.id
JOIN Products P  ON O.product_id = P.id
WHERE O.order_date >= '2024-01-01';
```

**メリット:**
- 結合条件と検索条件が分離 → 可読性向上
- 結合条件の漏れに気づきやすい

### 検出方法

#### 1. EXPLAIN で rows を確認

```sql
EXPLAIN FORMAT=TREE
SELECT *
FROM TableA A, TableB B, TableC C
WHERE A.id = B.id;
```

**出力例:**
```
-> Inner hash join  (cost=10000 rows=100000)  ← 異常に大きい
    -> Table scan on C  (cost=10 rows=1000)
    -> Hash
        -> Inner hash join  (cost=20 rows=100)
            -> Table scan on A
            -> Hash
                -> Table scan on B
```

**判断基準:**
- `rows` が想定より **10倍以上大きい** → 直積の疑い
- `cost` が異常に高い

#### 2. 実行時間で検出

```sql
-- テスト実行（LIMIT で被害を最小化）
SELECT *
FROM TableA A, TableB B, TableC C
WHERE A.id = B.id
LIMIT 10;
```

**判断基準:**
- 単純な結合なのに **1秒以上かかる** → 直積の疑い

#### 3. 結合条件数をチェック

```
結合条件数 = テーブル数 - 1
```

**例:**
- 3テーブル結合 → 最低2つの結合条件が必要
- 4テーブル結合 → 最低3つの結合条件が必要

```sql
-- ❌ 悪い例: 3テーブルなのに結合条件が1つ
FROM A, B, C WHERE A.id = B.id

-- ✅ 良い例: 3テーブルで結合条件が2つ
FROM A JOIN B ON A.id = B.id
       JOIN C ON B.id = C.id
```

### 判断フロー

```
テーブル数は3つ以上？
├─ NO  → 三角結合のリスクなし
└─ YES → 次へ

結合条件数 >= テーブル数 - 1？
├─ YES → OK
└─ NO  → 結合条件が不足（直積のリスク）

JOIN句を使っているか？
├─ YES → 可読性OK
└─ NO  → WHERE句結合 → JOIN句に書き換え推奨

EXPLAIN で rows が適切か？
├─ YES → OK
└─ NO  → 直積が発生している → 結合条件を追加
```

### まとめ

**やってはいけないこと:**
❌ WHERE句でのみ結合条件を記述（カンマ結合）
❌ 結合条件数 < テーブル数 - 1

**やるべきこと:**
✅ JOIN句で明示的に結合条件を記述
✅ `結合条件数 = テーブル数 - 1` を満たす
✅ EXPLAIN で rows を確認

**検出方法:**
1. EXPLAIN で `rows` が異常に大きい
2. 実行時間が予想外に長い
3. 結合条件数 < テーブル数 - 1

**参照:**
- [knowledge/join-algorithms.md](./join-algorithms.md#結合が遅い時のチェックリスト) - 意図せぬクロス結合の詳細
- [tasks/review-query.md](../tasks/review-query.md#4-join) - 結合チェックリスト

---

## サブクエリ・パラノイア

> 「SQLパフォーマンスの要諦: 1にI/O、2にI/O、3、4がなくて5にI/O」

### 概要

**サブクエリ・パラノイア（Subquery Paranoia）** とは、サブクエリを使うことでテーブルへの複数回アクセスや不要な結合が発生し、性能が劣化するアンチパターン。

**問題の本質:**
- 同じテーブルに複数回アクセス → **I/O増加**
- サブクエリとの結合が発生 → 実行計画変動リスク
- 一時領域の使用 → TEMP落ちリスク
- インデックスが効かない → 最適化されない

### 問題のパターン

#### パターン1: サブクエリで集約 → 結合

```sql
-- ❌ 悪い例: 最小値をサブクエリで取得して結合
SELECT R1.cust_id, R1.seq, R1.price
FROM Receipts R1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq
    FROM Receipts  -- ← Receiptsに2回アクセス
    GROUP BY cust_id
) R2
ON R1.cust_id = R2.cust_id
AND R1.seq = R2.min_seq;
```

**何が起きるか:**
```
1. Receiptsテーブルをスキャン（サブクエリ）
2. MIN値を計算して一時テーブル作成
3. Receiptsテーブルを再度スキャン（R1として）
4. 一時テーブルと結合

→ テーブルアクセス2回、結合1回
```

**EXPLAIN例:**
```
-> Inner hash join  (cost=500 rows=100)
    -> Table scan on R1  (cost=200 rows=10000)  ← 1回目
    -> Hash
        -> Table scan on Receipts  (cost=200 rows=10000)  ← 2回目
            -> Aggregate using temp table
```

#### パターン2: 相関サブクエリ

```sql
-- ❌ 悪い例: 相関サブクエリ
SELECT cust_id, seq, price
FROM Receipts R1
WHERE seq = (
    SELECT MIN(seq)
    FROM Receipts R2
    WHERE R1.cust_id = R2.cust_id  -- 相関条件
);
```

**何が起きるか:**
- 外側の行ごとに内側のSQLを実行（ループ）
- やっぱりテーブルに2回アクセス
- 実行計画は結合とほぼ同じ

**EXPLAIN例:**
```
-> Filter: (R1.seq = (select #2))
    -> Table scan on R1  (cost=200 rows=10000)  ← 1回目
    -> Select #2
        -> Aggregate
            -> Filter: (R1.cust_id = R2.cust_id)
                -> Table scan on R2  (cost=200 rows=10000)  ← 2回目
```

### 解決策：ウィンドウ関数で結合をなくす

#### ✅ 良い例: ROW_NUMBER で置き換え

```sql
SELECT cust_id, seq, price
FROM (
    SELECT cust_id, seq, price,
           ROW_NUMBER() OVER (
               PARTITION BY cust_id
               ORDER BY seq
           ) AS row_seq
    FROM Receipts
) WORK
WHERE WORK.row_seq = 1;
```

**改善点:**
- ✅ テーブルアクセス**1回だけ**
- ✅ 結合なし
- ✅ 実行計画がシンプルで安定
- ✅ **I/Oが最小化**

**EXPLAIN例:**
```
-> Filter: (WORK.row_seq = 1)
    -> Window aggregate
        -> Table scan on Receipts  (cost=200 rows=10000)  ← 1回のみ
```

**性能差:**
```
サブクエリ結合:   テーブルアクセス2回 → 約2倍遅い
ウィンドウ関数:   テーブルアクセス1回 → 高速
```

### サブクエリが許容されるケース

#### 例外: 結合前に行数を大幅に絞れる場合

```sql
-- ❌ 解1: 結合してから集約（遅い可能性）
SELECT C.co_cd, MAX(S.emp_count)
FROM Companies C
INNER JOIN Shops S ON C.co_cd = S.co_cd
WHERE main_flg = 'Y'
GROUP BY C.co_cd;
-- 結合: 500万行 × 100行 → その後絞り込み

-- ✅ 解2: 先に集約してから結合（速い可能性）
SELECT C.co_cd, CSUM.total_emp
FROM Companies C
INNER JOIN (
    SELECT co_cd, SUM(emp_count) AS total_emp
    FROM Shops
    WHERE main_flg = 'Y'  -- 先に絞り込み
    GROUP BY co_cd
) CSUM
ON C.co_cd = CSUM.co_cd;
-- 結合: 1,000行 × 100行
```

**解2が速い理由:**
- 結合対象が 500万行 → 1,000行 に減る
- 結合コストが大幅に下がる
- **I/Oが削減される**

**判断基準:**
```
サブクエリで絞り込める行数が多いか？
├─ YES（10倍以上削減） → サブクエリ有効
└─ NO（削減効果小）   → ウィンドウ関数で結合回避
```

### 検出方法

#### 1. EXPLAINでテーブルアクセス回数を確認

```sql
EXPLAIN FORMAT=TREE
SELECT R1.cust_id, R1.seq, R1.price
FROM Receipts R1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq
    FROM Receipts
    GROUP BY cust_id
) R2
ON R1.cust_id = R2.cust_id
AND R1.seq = R2.min_seq;
```

**確認ポイント:**
- 同じテーブル名が**2回以上**出現 → サブクエリ・パラノイア

#### 2. クエリ構造をチェック

```
FROM句にサブクエリがある？
├─ NO  → OK
└─ YES → 次へ

サブクエリ内のテーブルとFROM句のテーブルが同じ？
├─ NO  → OK（別テーブルの結合）
└─ YES → サブクエリ・パラノイア
```

### 判断フロー

```
サブクエリを使っている？
├─ NO  → OK
└─ YES → 次へ

同じテーブルに複数回アクセスしている？
├─ NO  → 次へ
└─ YES → ウィンドウ関数で置き換え検討

サブクエリで結合が発生している？
├─ NO  → 次へ
└─ YES → ウィンドウ関数で置き換え検討

結合前に行数を大幅に絞れる？（10倍以上）
├─ YES → サブクエリ有効（そのまま）
└─ NO  → ウィンドウ関数で置き換え
```

### まとめ

**やってはいけないこと:**
❌ 同じテーブルに複数回アクセス
❌ サブクエリとの不要な結合
❌ 思考の補助として書いたサブクエリをそのまま実行

**やるべきこと:**
✅ ウィンドウ関数で結合を消去
✅ テーブルアクセスを1回に
✅ I/Oを最小化

**例外（サブクエリが有効）:**
✅ 結合前に行数を大幅に絞れる場合（10倍以上）

**心構え:**
- 「困難は分割するな」
- 思考の補助としてサブクエリを使うのはOK
- 最終的には統合してシンプルにする

**参照:**
- [knowledge/subquery-problems.md](./subquery-problems.md) - サブクエリの問題点の詳細
- [knowledge/window-functions.md](./window-functions.md#サブクエリからウィンドウ関数への置き換え) - ウィンドウ関数への置き換えパターン
- [tasks/review-query.md](../tasks/review-query.md#5-サブクエリ) - サブクエリチェックリスト

---

## シーケンス/IDENTITY列の乱用

> 「シーケンス・IDENTITY列は排他制御のボトルネックとホットスポット問題を引き起こす」

### 概要

**シーケンスオブジェクト**と**IDENTITY列**（MySQL: AUTO_INCREMENT）は、自動で連番を生成する便利な機能だが、性能問題の火薬庫でもある。

**問題の本質:**
- 排他制御がボトルネック
- インデックスのホットスポット問題
- 分散DBでは特に深刻
- スケーラビリティを損なう

---

### 問題点1: 排他制御がボトルネック

#### シーケンスの動作

```
トランザクション1: SELECT nextval('seq_id')  → 1 を取得
トランザクション2: SELECT nextval('seq_id')  → 待機...
トランザクション1: COMMIT
トランザクション2: → 2 を取得
```

**問題:**
- シーケンス取得時に**排他ロック**が発生
- 並行トランザクションが待たされる
- 高負荷時のボトルネック

#### 実測例

```
並行トランザクション数とスループット:
  1トランザクション:   1000 TPS
  10トランザクション:  500 TPS  （半減）
  100トランザクション: 100 TPS  （1/10）
```

**原因:**
- シーケンス値の採番が直列化される
- 並行度が上がると性能が劣化

---

### 問題点2: インデックスのホットスポット問題

#### 連番キーの挿入

```sql
CREATE TABLE Orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    ...
);

-- 挿入順序
INSERT INTO Orders VALUES (1, ...);
INSERT INTO Orders VALUES (2, ...);
INSERT INTO Orders VALUES (3, ...);
...
```

**何が起きるか:**
```
B-Treeインデックス:
              [root]
             /      \
    [1-1000]        [1001-2000]
                           ↑
                    常にここに挿入（ホットスポット）
```

**問題:**
- インデックスの**最右端のページ**にのみ挿入
- ページ分割が頻発
- バッファキャッシュが効かない
- 排他ロックの競合が発生

#### UUIDとの比較

```
連番キー:
  - 挿入位置が集中 → ホットスポット
  - 高速だが並行性が低い

UUID:
  - 挿入位置が分散 → ホットスポット回避
  - インデックスサイズ大（16バイト vs 4バイト）
  - シーケンシャルスキャンが遅い
```

---

### 問題点3: 分散DBでの問題

#### NewSQL/分散DBの課題

```
ノード1: シーケンス値 1, 2, 3...
ノード2: シーケンス値 ???
ノード3: シーケンス値 ???
```

**問題:**
- 分散環境で一意な連番を生成するのは**非常に困難**
- ノード間の調整が必要 → ネットワーク遅延
- スケールアウトの障害

#### 分散DBでの代替案

```
1. UUID/GUID:
   - ノード間調整不要
   - ランダム生成で一意性保証

2. Snowflake ID:
   - タイムスタンプ + ノードID + 連番
   - ソート可能なUUID

3. 範囲分割:
   - ノード1: 1-1000000
   - ノード2: 1000001-2000000
   - 事前に範囲を割り当て
```

---

### 問題点4: 欠番の発生

#### ROLLBACKによる欠番

```sql
BEGIN;
INSERT INTO Orders (order_id, ...) VALUES (100, ...);
-- order_id = 100 が採番される
ROLLBACK;
-- 100は使われず欠番になる

BEGIN;
INSERT INTO Orders (order_id, ...) VALUES (?, ...);
-- order_id = 101 が採番される（100は飛ばされる）
```

**問題:**
- ロールバックやエラーで欠番が発生
- 連番の連続性が保証されない
- 「ID=100が存在しない」トラブル

---

### 解決策と代替案

#### 1. シーケンスよりIDENTITY列を使う（MySQL: AUTO_INCREMENT）

```sql
-- ❌ シーケンスオブジェクト（PostgreSQL）
CREATE SEQUENCE order_id_seq;
INSERT INTO Orders (order_id, ...)
VALUES (nextval('order_id_seq'), ...);

-- ✅ IDENTITY列（MySQL: AUTO_INCREMENT）
CREATE TABLE Orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    ...
);
INSERT INTO Orders (...) VALUES (...);
-- order_idは自動採番
```

**理由:**
- IDENTITY列はDBMSが最適化
- キャッシュやバッファが効く

#### 2. キャッシュオプションを使う（PostgreSQL）

```sql
CREATE SEQUENCE order_id_seq CACHE 100;
```

**効果:**
- 100個分を事前にメモリに確保
- 排他ロックの頻度が1/100に

**注意:**
- サーバー再起動で100個飛ぶ
- 欠番が増える

#### 3. NOORDERオプション（Oracle）

```sql
CREATE SEQUENCE order_id_seq NOORDER;
```

**効果:**
- 順序保証をなくす代わりに性能向上
- 並行性が向上

#### 4. UUIDを使う

```sql
CREATE TABLE Orders (
    order_id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    ...
);
```

**メリット:**
- 排他制御不要
- 分散環境でも一意性保証
- ホットスポット回避

**デメリット:**
- インデックスサイズ大（16バイト）
- 可読性低い
- シーケンシャルスキャンが遅い

#### 5. ROW_NUMBERで後付け連番

```sql
-- 連番はビュー定義で付与
CREATE VIEW OrdersWithSeq AS
SELECT ROW_NUMBER() OVER (ORDER BY created_at) AS seq,
       order_id, ...
FROM Orders;
```

**メリット:**
- 排他制御不要
- ホットスポット回避
- 欠番なし（常に詰めた連番）

**デメリット:**
- 毎回計算が必要
- UPDATEで順序が変わる可能性

---

### 判断フロー

```
連番が本当に必要か？
├─ NO  → UUID/GUID を使う
└─ YES → 次へ

順序の厳密性が必要か？
├─ NO  → NOORDER/CACHE オプション
└─ YES → 次へ

分散環境か？
├─ YES → UUID/Snowflake ID
└─ NO  → 次へ

高負荷・高並行性か？
├─ YES → UUID または キャッシュ付きシーケンス
└─ NO  → IDENTITY列（AUTO_INCREMENT）を慎重に使う
```

---

### まとめ

**本書のスタンス:**
```
シーケンスオブジェクト・IDENTITY列は極力使うな
```

**理由:**
❌ 排他制御がボトルネック
❌ インデックスのホットスポット問題
❌ 分散DBでスケールしない
❌ 欠番が発生する

**どうしても使うなら:**
1. **IDENTITY列 > シーケンスオブジェクト**（DBMSの最適化が効く）
2. **CAC HEオプション**を使う（排他ロック削減）
3. **NOORDERオプション**を使う（順序保証を緩める）

**代替案:**
✅ **UUID/GUID**（分散環境で最適）
✅ **Snowflake ID**（ソート可能なUUID）
✅ **ROW_NUMBER**（後付け連番）
✅ **タイムスタンプ+ランダム値**

**設計方針:**
- 「連番が本当に必要か？」を問い直す
- ビジネス要件とパフォーマンスのトレードオフ
- 分散環境を見据えた設計

---

**参照:**
- [knowledge/window-functions.md](./window-functions.md#sqlと順序順序処理の応用パターン) - ROW_NUMBERによる連番生成
- [examples/common-patterns.md](../examples/common-patterns.md) - ウィンドウ関数パターン

---

## スーパーソルジャー病

> 「賢いデータ構造と間抜けなコードのほうが、その逆よりずっとまし」

### 概要

**スーパーソルジャー病（Super Soldier Syndrome）** とは、難しい問題を難しいまま解こうとし、SQLで何とかしようとして複雑なクエリを書き、データモデルの問題をコードで解決しようとするアンチパターン。

**問題の本質:**
- データモデルの問題をSQLで無理やり解決しようとする
- 複雑なクエリを書くことに満足してしまう
- 「一歩引いてモデルを見直す」という発想がない
- コーディングの前にモデリングを考えない

---

### 症状: SQLで頑張る

#### 問題例: 注文ごとの商品数を取得したい

```sql
-- ❌ SQLで頑張る（結合 + 集約）
SELECT O.order_id, O.order_name, COUNT(*) AS item_count
FROM Orders O
JOIN OrderReceipts ORC ON O.order_id = ORC.order_id
GROUP BY O.order_id, O.order_name;
```

**何が起きるか:**
- 毎回結合が発生
- 集約処理が必要
- インデックスが効きにくい
- 実行計画が変動しやすい

**EXPLAIN例:**
```
-> Group aggregate
    -> Inner hash join  (cost=500 rows=1000)
        -> Table scan on O  (cost=100 rows=100)
        -> Hash
            -> Table scan on ORC  (cost=200 rows=1000)
```

---

### 処方箋: モデルを変える

#### 本当の解決策: Ordersテーブルに item_count 列を追加

```sql
-- テーブル定義を変更
ALTER TABLE Orders ADD COLUMN item_count INT DEFAULT 0;

-- 既存データの更新
UPDATE Orders O
SET item_count = (
    SELECT COUNT(*)
    FROM OrderReceipts ORC
    WHERE ORC.order_id = O.order_id
);

-- ✅ シンプルなクエリ（結合不要）
SELECT order_id, order_name, item_count
FROM Orders;
```

**改善点:**
- ✅ 結合不要
- ✅ SELECT一発で取得
- ✅ インデックスが効く
- ✅ 実行計画が安定
- ✅ パフォーマンスが良い

**EXPLAIN例:**
```
-> Table scan on Orders  (cost=100 rows=100)
```

---

### モデル変更のトレードオフ

#### メリット

✅ **SQLがシンプルになる**
- 複雑な結合・集約が不要
- 可読性が向上
- メンテナンスしやすい

✅ **パフォーマンスが良くなる**
- I/Oが削減される
- インデックスが効きやすい
- 実行計画が安定

✅ **スケーラビリティが向上**
- 負荷が分散される
- キャッシュが効きやすい

#### デメリット

❌ **更新コストが増える（冗長データの同期）**
```sql
-- 商品追加時
INSERT INTO OrderReceipts (...) VALUES (...);
UPDATE Orders SET item_count = item_count + 1 WHERE order_id = ?;

-- 商品削除時
DELETE FROM OrderReceipts WHERE receipt_id = ?;
UPDATE Orders SET item_count = item_count - 1 WHERE order_id = ?;
```

❌ **タイムラグが発生する（リアルタイム性の問題）**
- 集計列の更新タイミングによってはズレが生じる
- トランザクション管理が複雑になる
- バッチ更新の場合は特に注意

❌ **後からの変更は大変**
- 開発終盤・本番運用中は特に困難
- データ移行が必要
- ダウンタイムが発生する可能性

→ **鉄は熱いうちに打て（最初の設計が肝心）**

---

### 判断フロー

```
毎回結合+集約が必要なクエリ？
├─ YES → 頻繁に実行される？
│        ├─ YES → 集計列追加を検討
│        └─ NO  → そのままでも許容
│
└─ NO  → そのまま

集計列を追加する場合:
  更新頻度は？
    ├─ 低い（日次バッチ等） → 集計列追加が有効
    └─ 高い（リアルタイム） → トレードオフを慎重に検討

  リアルタイム性は必要？
    ├─ YES → ビューまたはキャッシュを検討
    └─ NO  → 集計列追加が有効
```

---

### 代替案: マテリアライズドビュー

集計列を追加する代わりに、**マテリアライズドビュー（実体化ビュー）** を使う方法もある。

```sql
-- MySQL 8.0+ の場合（近似）
CREATE TABLE OrderSummary AS
SELECT order_id, order_name, COUNT(*) AS item_count
FROM Orders O
JOIN OrderReceipts ORC ON O.order_id = ORC.order_id
GROUP BY O.order_id, O.order_name;

-- 定期的にリフレッシュ
TRUNCATE TABLE OrderSummary;
INSERT INTO OrderSummary
SELECT order_id, order_name, COUNT(*) AS item_count
FROM Orders O
JOIN OrderReceipts ORC ON O.order_id = ORC.order_id
GROUP BY O.order_id, O.order_name;
```

**メリット:**
- 元のテーブル構造を変更しない
- リフレッシュタイミングを制御できる

**デメリット:**
- 別テーブルの管理が必要
- リフレッシュ中のデータ不整合

---

### 名言

> 「賢いデータ構造と間抜けなコードのほうが、その逆よりずっとまし」
>
> 「フローチャートだけ見せてテーブルを見せないなら煙に巻かれたまま」

---

### 教訓

**1. データモデルがコードを決める（その逆ではない）**
- テーブル設計が良ければ、SQLはシンプルになる
- テーブル設計が悪ければ、どんなにSQLを工夫しても限界がある

**2. 間違ったモデルはコーディングで正せない**
- モデルの問題はモデルで解決する
- コードで無理やり解決しようとしない

**3. スーパーソルジャーより正しい戦略を選ぶ将官になれ**
- 難しい問題を難しいまま解かない
- 一歩引いて「そもそもテーブル設計おかしくない？」と考える
- 最初の設計段階でモデリングを見直す

---

### 検出方法

#### 1. クエリの複雑さ

```
複雑な結合+集約が毎回必要？
  ├─ YES → モデルを見直す
  └─ NO  → OK
```

#### 2. パフォーマンス問題

```
特定のクエリが常に遅い？
  ├─ YES → インデックス追加で解決する？
  │        ├─ NO  → モデルを見直す
  │        └─ YES → インデックス追加
  │
  └─ NO  → OK
```

#### 3. 実行頻度

```
同じパターンの集計クエリを頻繁に実行している？
  ├─ YES → 集計列追加を検討
  └─ NO  → そのまま
```

---

### まとめ

**スーパーソルジャー病の症状:**
❌ 難しい問題を難しいまま解こうとする
❌ SQLで何とかしようとして複雑なクエリを書く
❌ データモデルの問題をコードで解決しようとする

**処方箋:**
✅ 一歩引いて「そもそもテーブル設計おかしくない？」と考える
✅ コーディングの前にモデリングを見直す
✅ 鉄は熱いうちに打て（最初の設計が肝心）

**モデル変更の判断:**
- メリット: SQLシンプル、パフォーマンス向上、実行計画安定
- デメリット: 更新コスト増加、タイムラグ発生、後からの変更は大変
- トレードオフを慎重に検討する

**参照:**
- [tasks/review-query.md](../tasks/review-query.md#10-データモデルスーパーソルジャー病) - データモデルチェックリスト
