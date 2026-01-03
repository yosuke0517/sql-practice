# 実行計画の読み方

## 目的
EXPLAIN出力を読み解き、クエリのボトルネックを特定する

---

## EXPLAIN/EXPLAIN ANALYZEの実行方法

### MySQL

#### 基本形（従来形式）
```sql
EXPLAIN
SELECT * FROM shops WHERE rating >= 4.5;
```

**出力:** テーブル形式（カラム: id, select_type, table, type, key, rows, Extra）

---

#### FORMAT=TREE（推奨）
```sql
EXPLAIN FORMAT=TREE
SELECT * FROM shops WHERE rating >= 4.5;
```

**出力:** ツリー形式（実行順序がわかりやすい）

```
-> Filter: (shops.rating >= 4.5)  (cost=6.35 rows=20)
    -> Table scan on shops  (cost=6.35 rows=60)
```

**読む順序:** 下から上（インデントが深い方から）

---

#### FORMAT=JSON
```sql
EXPLAIN FORMAT=JSON
SELECT * FROM shops WHERE rating >= 4.5;
```

**出力:** JSON形式（詳細情報、プログラムでパース可能）

---

#### EXPLAIN ANALYZE（実測値付き）
```sql
EXPLAIN ANALYZE
SELECT * FROM shops WHERE rating >= 4.5;
```

**特徴:**
- **実際にクエリを実行**して実測値を取得
- `actual time`, `actual rows` を含む
- 推定（rows）と実測（actual rows）の差を確認できる

**注意:** 本番環境では使用注意（実際にデータを取得するため）

---

### PostgreSQL（補足）

#### 基本形
```sql
EXPLAIN
SELECT * FROM shops WHERE rating >= 4.5;
```

#### ANALYZE付き（実測値）
```sql
EXPLAIN ANALYZE
SELECT * FROM shops WHERE rating >= 4.5;
```

#### BUFFERS付き（I/O情報）
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM shops WHERE rating >= 4.5;
```

**出力例:**
```
Seq Scan on shops  (cost=0.00..1.75 rows=20 width=...)
                   (actual time=0.012..0.034 rows=18 loops=1)
  Filter: (rating >= 4.5)
  Rows Removed by Filter: 42
  Buffers: shared hit=1
Planning Time: 0.123 ms
Execution Time: 0.056 ms
```

---

## 実行計画の読み方（MySQL）

### 従来形式（テーブル形式）の見方

#### サンプルクエリ
```sql
EXPLAIN
SELECT S.shop_name, R.reserve_name
FROM Reservations R
JOIN Shops S ON R.shop_id = S.shop_id
WHERE S.rating >= 4.5;
```

#### 出力例
```
+----+-------------+-------+------+---------------+------+---------+------+------+-------------+
| id | select_type | table | type | key           | rows | Extra                           |
+----+-------------+-------+------+---------------+------+---------+------+------+-------------+
|  1 | SIMPLE      | S     | ALL  | NULL          |   60 | Using where                     |
|  1 | SIMPLE      | R     | ref  | idx_shop_id   |    1 | NULL                            |
+----+-------------+-------+------+---------------+------+---------+------+------+-------------+
```

---

### 主要カラムの意味

#### id
**意味:** SELECT文の識別子

| 値 | 説明 |
|----|------|
| 1 | メインクエリ |
| 2, 3, ... | サブクエリ（数字が大きいほど内側） |

**読む順序:**
- idが**大きい方から**読む（サブクエリ → メイン）
- idが同じ場合は**上から下**へ読む

---

#### select_type
**意味:** SELECT文の種類

| 値 | 説明 |
|-------|------|
| **SIMPLE** | 単純なSELECT（サブクエリなし、UNIONなし） |
| **PRIMARY** | 最外側のSELECT |
| **SUBQUERY** | サブクエリの最初のSELECT |
| **DERIVED** | FROM句のサブクエリ（派生テーブル） |
| **UNION** | UNION の2番目以降のSELECT |

---

#### table
**意味:** アクセスするテーブル名

| 値 | 説明 |
|-------|------|
| テーブル名 | 実際のテーブル |
| `<derivedN>` | 派生テーブル（FROM句のサブクエリ） |
| `<subqueryN>` | サブクエリの実体化テーブル |

---

#### type（アクセスタイプ）
**意味:** テーブルへのアクセス方法（**最重要カラム**）

**速度順（速い → 遅い）:**

| type | 説明 | 速度 | 検査行数 |
|------|------|------|---------|
| **system** | テーブルに1行のみ（システムテーブル） | ⚡ 最速 | 1行 |
| **const** | PRIMARY KEYまたはUNIQUEインデックスで1行のみ | ⚡ 最速 | 1行 |
| **eq_ref** | 結合時にPRIMARY KEYまたはUNIQUEインデックスで1行 | ✅ 高速 | 1行 |
| **ref** | 非ユニークインデックスで検索（複数行） | ✅ 高速 | 少数行 |
| **range** | インデックスを使った範囲検索（`BETWEEN`, `>`, `<`） | ○ 普通 | 範囲内の行 |
| **index** | インデックス全件スキャン | △ 遅い | 全行 |
| **ALL** | テーブル全件スキャン（**最悪**） | ❌ 最遅 | 全行 |

---

##### const（定数検索）
```sql
EXPLAIN
SELECT * FROM shops WHERE shop_id = 1;
```

**条件:**
- PRIMARY KEYまたはUNIQUE KEY
- `=` で定数と比較

**特徴:**
- 最速（1行のみ取得）
- オプティマイザがクエリ最適化時に定数として扱う

---

##### eq_ref（結合時の一意検索）
```sql
EXPLAIN
SELECT *
FROM Reservations R
JOIN Shops S ON R.shop_id = S.shop_id;
```

**条件:**
- 結合時にPRIMARY KEYまたはUNIQUE KEYを使用
- 1対1の関係

**特徴:**
- 結合で最も効率的
- 内部表から**必ず1行のみ**取得

---

##### ref（非ユニークインデックス検索）
```sql
EXPLAIN
SELECT * FROM Reservations WHERE shop_id = 1;
```

**条件:**
- 非ユニークインデックスを使用
- 複数行がヒットする可能性

**特徴:**
- インデックスを使うため高速
- 等価比較（`=`）で使用

---

##### range（範囲検索）
```sql
EXPLAIN
SELECT * FROM shops WHERE rating BETWEEN 4.0 AND 5.0;
```

**条件:**
- インデックスを使った範囲検索
- `BETWEEN`, `>`, `<`, `IN`, `LIKE '前方%'`

**特徴:**
- インデックスを使うため比較的高速
- 検査行数は範囲による

---

##### index（インデックス全件スキャン）
```sql
EXPLAIN
SELECT shop_id FROM shops;
```

**条件:**
- インデックスの全行をスキャン
- SELECT句の列がインデックスに含まれる（カバリングインデックス）

**特徴:**
- テーブル本体にアクセスしないため、ALLより速い
- それでもフルスキャン

---

##### ALL（テーブル全件スキャン）
```sql
EXPLAIN
SELECT * FROM shops WHERE shop_name LIKE '%東京%';
```

**条件:**
- インデックスが使えない
- WHERE句なし

**特徴:**
- **最も遅い**
- 全行をスキャン
- 大きなテーブルでは致命的

---

#### key（使用されるインデックス）
**意味:** 実際に使われるインデックス名

| 値 | 説明 |
|-------|------|
| インデックス名 | そのインデックスが使われる |
| **NULL** | ❌ インデックスが使われない（フルスキャン） |

**チェック方法:**
```sql
SHOW INDEX FROM shops;
```

---

#### rows（推定検査行数）
**意味:** オプティマイザが**推定**する検査行数

**注意:**
- あくまで推定値（実際とズレることがある）
- 統計情報が古いと不正確

**確認ポイント:**
- `rows` が大きい → ボトルネックの可能性
- 結合時に `rows` の積が大きい → クロス結合の可能性

**例:**
```
| table | rows |
|-------|------|
| A     | 100  |
| B     | 1000 |
```
→ 駆動表Aの各行に対して、Bを1000行スキャン → 合計100,000行アクセス

---

#### Extra（追加情報）
**意味:** クエリの実行方法に関する追加情報

---

##### ✅ 良いサイン

**Using index（カバリングインデックス）**
```
Extra: Using index
```

**意味:**
- SELECT句の列が全てインデックスに含まれる
- テーブル本体にアクセスせずにインデックスだけで完結

**例:**
```sql
-- インデックス: idx(shop_id, shop_name)
SELECT shop_id, shop_name FROM shops WHERE shop_id = 1;
```

---

**Using index condition（インデックス条件下げ）**
```
Extra: Using index condition
```

**意味:**
- インデックスで絞り込んだ後、さらに条件でフィルタリング
- MySQL 5.6+ の最適化（Index Condition Pushdown）

---

##### ⚠️ 要注意サイン

**Using where**
```
Extra: Using where
```

**意味:**
- WHERE句でフィルタリングしている
- それ自体は悪くないが、`type = ALL` と併用だと遅い

**例:**
```sql
-- type = ALL, Extra = Using where → 全件スキャン後にフィルタリング
SELECT * FROM shops WHERE shop_name LIKE '%東京%';
```

---

##### ❌ 危険なサイン

**Using filesort（ソート処理）**
```
Extra: Using filesort
```

**意味:**
- ORDER BYでソートが必要
- メモリ内でソート（小規模）またはディスク（大規模）

**危険度:**
- データ量が大きいと**TEMP落ち**（ディスク書き込み）
- パフォーマンス劇的悪化

**対策:**
1. インデックスでソート済みにする（ORDER BY句の列にインデックス）
2. ソート対象を減らす（WHERE句で絞り込み）
3. ワーキングメモリを増やす（`sort_buffer_size`）

---

**Using temporary（一時テーブル作成）**
```
Extra: Using temporary
```

**意味:**
- GROUP BY、DISTINCT、サブクエリで一時テーブル作成
- メモリ内（小規模）またはディスク（大規模）

**危険度:**
- データ量が大きいと**TEMP落ち**（ディスク書き込み）
- I/O増加でパフォーマンス劇的悪化

**対策:**
1. GROUP BY句の列にインデックス
2. データを絞り込む（WHERE句）
3. ワーキングメモリを増やす（`tmp_table_size`, `max_heap_table_size`）

**参照:** [knowledge/temp-fall.md](../knowledge/temp-fall.md)

---

**Using filesort; Using temporary（最悪の組み合わせ）**
```
Extra: Using filesort; Using temporary
```

**意味:**
- 一時テーブル作成 → ソート の2段階処理
- 最もコストが高い

**例:**
```sql
-- GROUP BY + ORDER BY（異なる列）
SELECT shop_id, COUNT(*) AS cnt
FROM Reservations
GROUP BY shop_id
ORDER BY cnt DESC;
```

**対策:**
1. GROUP BYとORDER BYを同じ列にする
2. インデックスを活用
3. サブクエリで分割

---

### FORMAT=TREE の読み方

#### サンプル出力
```
-> Inner hash join (R.shop_id = S.shop_id)  (cost=2.7 rows=2)
    -> Table scan on R  (cost=0.175 rows=10)
    -> Hash
        -> Filter: (S.rating >= 4.5)  (cost=0.45 rows=2)
            -> Table scan on S  (cost=0.45 rows=60)
```

#### 読む順序
**下から上（インデントが深い方から）**

1. `Table scan on S` → Shopsテーブル全件スキャン（60行）
2. `Filter: (S.rating >= 4.5)` → 条件でフィルタリング（2行残る）
3. `Hash` → ハッシュテーブル作成
4. `Table scan on R` → Reservationsテーブル全件スキャン（10行）
5. `Inner hash join` → ハッシュ結合で2テーブルを結合

#### 主要キーワード

| キーワード | 意味 |
|----------|------|
| **Table scan** | テーブル全件スキャン（❌ 遅い） |
| **Index lookup** | インデックス検索（✅ 速い） |
| **Index range scan** | インデックス範囲検索 |
| **Filter** | WHERE句でフィルタリング |
| **Nested loop** | ネステッドループ結合 |
| **Inner hash join** | ハッシュ結合 |
| **Sort** | ソート処理 |
| **Aggregate** | 集約処理（GROUP BY） |
| **cost** | 推定処理コスト |
| **rows** | 推定検査行数 |

**参照:** [knowledge/join-algorithms.md](../knowledge/join-algorithms.md)

---

## 危険なサインの見分け方

### 一覧表（優先度順）

| 危険サイン | 症状 | 原因 | 影響度 |
|----------|------|------|--------|
| **type = ALL** | テーブル全件スキャン | インデックス未使用 | ❌❌❌ 最悪 |
| **Using filesort; Using temporary** | 一時テーブル作成 + ソート | GROUP BY + ORDER BY（異なる列） | ❌❌❌ 最悪 |
| **rows が異常に大きい** | 推定検査行数が多い | クロス結合、WHERE句なし | ❌❌ 深刻 |
| **key = NULL** | インデックス未使用 | WHERE句の列にインデックスなし | ❌❌ 深刻 |
| **Using temporary** | 一時テーブル作成 | GROUP BY、DISTINCT | ❌ 要注意 |
| **Using filesort** | ソート処理 | ORDER BY | ❌ 要注意 |
| **Table scan on 大きいテーブル** | 全件スキャン | インデックス未使用 | ❌❌ 深刻 |

---

### 詳細チェックリスト

#### ❌ type = ALL（フルテーブルスキャン）
```
| type | table | rows |
|------|-------|------|
| ALL  | shops | 100000 |
```

**問題:**
- 全行をスキャン
- 大きなテーブルで致命的

**確認ポイント:**
- [ ] WHERE句に条件があるか
- [ ] インデックスが定義されているか（`SHOW INDEX FROM table`）
- [ ] インデックスが効かない条件ではないか（参照: [index-strategies.md](../knowledge/index-strategies.md)）
  - LIKE中間一致 `'%keyword%'`
  - 列を加工 `YEAR(date) = 2024`
  - 否定形 `<>`, `NOT IN`
  - IS NULL
  - 選択率が高い

**対策:**
1. WHERE句の列にインデックス追加
2. WHERE句の条件を見直し（インデックスが効く形に）
3. カバリングインデックス

---

#### ❌ key = NULL（インデックス未使用）
```
| type | key  | rows |
|------|------|------|
| ALL  | NULL | 50000 |
```

**問題:**
- インデックスが使われていない
- type = ALL と併用で最悪

**対策:**
1. `SHOW INDEX FROM table` でインデックス確認
2. WHERE句の列にインデックス追加
3. 複合インデックスの順序確認

---

#### ❌ rows が異常に大きい
```
| table | rows   |
|-------|--------|
| A     | 1000   |
| B     | 100000 |
```

**問題:**
- クロス結合が発生している可能性
- 推定検査行数が 1000 × 100000 = 1億行

**確認ポイント:**
- [ ] 結合条件数 = テーブル数 - 1 を満たすか
- [ ] FROM句に孤立したテーブルがないか

**対策:**
1. 結合条件を追加
2. WHERE句で絞り込み

**参照:** [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#意図せぬクロス結合三角結合)

---

#### ❌ Using filesort
```
Extra: Using filesort
```

**問題:**
- ソート処理が発生
- データ量が大きいとTEMP落ち

**確認ポイント:**
- [ ] ORDER BY句がある
- [ ] インデックスでソート済みか

**対策:**
1. ORDER BY句の列にインデックス追加
2. WHERE句で絞り込み（ソート対象を減らす）
3. `sort_buffer_size` を増やす（最終手段）

---

#### ❌ Using temporary
```
Extra: Using temporary
```

**問題:**
- 一時テーブル作成
- データ量が大きいとTEMP落ち

**確認ポイント:**
- [ ] GROUP BY、DISTINCT がある
- [ ] サブクエリを使っている

**対策:**
1. GROUP BY句の列にインデックス追加
2. WHERE句で絞り込み（一時テーブルのサイズを減らす）
3. `tmp_table_size`, `max_heap_table_size` を増やす（最終手段）

**参照:** [knowledge/temp-fall.md](../knowledge/temp-fall.md)

---

#### ❌ Using filesort; Using temporary（最悪の組み合わせ）
```
Extra: Using filesort; Using temporary
```

**問題:**
- 一時テーブル作成 → ソート の2段階
- 最もコストが高い

**対策:**
1. GROUP BYとORDER BYを同じ列にする
2. インデックスを活用
3. サブクエリで処理を分割

---

## 改善の指針

### 危険サイン別の対処法

#### type = ALL → インデックス追加

**Before:**
```sql
-- type = ALL
EXPLAIN
SELECT * FROM shops WHERE rating >= 4.5;
```

**After:**
```sql
-- インデックス追加
CREATE INDEX idx_rating ON shops(rating);

-- type = range に改善
EXPLAIN
SELECT * FROM shops WHERE rating >= 4.5;
```

---

#### key = NULL → インデックス確認

**手順:**
1. インデックスの存在確認
```sql
SHOW INDEX FROM shops;
```

2. なければ追加
```sql
CREATE INDEX idx_rating ON shops(rating);
```

3. あるのに使われない場合 → インデックスが効かない条件か確認
```sql
-- ❌ 列を加工（インデックスが効かない）
WHERE YEAR(created_at) = 2024

-- ✅ 右辺で計算（インデックスが効く）
WHERE created_at >= '2024-01-01' AND created_at < '2025-01-01'
```

**参照:** [knowledge/index-strategies.md](../knowledge/index-strategies.md)

---

#### rows が大きい → WHERE句で絞り込み / 結合条件確認

**Before:**
```sql
-- rows = 1,000,000
SELECT * FROM orders WHERE status IN ('completed', 'pending', 'cancelled');
```

**After:**
```sql
-- 期間で絞り込み
SELECT * FROM orders
WHERE created_at >= '2024-01-01'
  AND status IN ('completed', 'pending', 'cancelled');
```

---

#### Using filesort → インデックスでソート済みに

**Before:**
```sql
-- Extra: Using filesort
EXPLAIN
SELECT * FROM orders ORDER BY created_at DESC;
```

**After:**
```sql
-- インデックス追加
CREATE INDEX idx_created_at ON orders(created_at);

-- Extra: Using index（ソート不要）
EXPLAIN
SELECT * FROM orders ORDER BY created_at DESC;
```

---

#### Using temporary → インデックス追加 / WHERE句で絞り込み

**Before:**
```sql
-- Extra: Using temporary
EXPLAIN
SELECT shop_id, COUNT(*) AS cnt
FROM Reservations
GROUP BY shop_id;
```

**After:**
```sql
-- インデックス追加
CREATE INDEX idx_shop_id ON Reservations(shop_id);

-- Extra: Using index（一時テーブル不要）
EXPLAIN
SELECT shop_id, COUNT(*) AS cnt
FROM Reservations
GROUP BY shop_id;
```

---

#### Using filesort; Using temporary → GROUP BYとORDER BYを統一

**Before:**
```sql
-- Extra: Using filesort; Using temporary
EXPLAIN
SELECT shop_id, COUNT(*) AS cnt
FROM Reservations
GROUP BY shop_id
ORDER BY cnt DESC;
```

**After（方法1）: サブクエリで分割**
```sql
EXPLAIN
SELECT * FROM (
    SELECT shop_id, COUNT(*) AS cnt
    FROM Reservations
    GROUP BY shop_id
) tmp
ORDER BY cnt DESC;
```

**After（方法2）: ウィンドウ関数で置き換え**
```sql
EXPLAIN
SELECT DISTINCT shop_id,
       COUNT(*) OVER (PARTITION BY shop_id) AS cnt
FROM Reservations
ORDER BY cnt DESC;
```

---

### 改善の優先順位

```
1位: インデックスの追加・修正
  → 最も即効性がある

2位: クエリの書き換え
  → サブクエリ → ウィンドウ関数
  → UNION → CASE式

3位: WHERE句で絞り込み
  → データ量を減らす

4位: ワーキングメモリの増加
  → TEMP落ち対策（最終手段）
```

---

## 実践例: 良い実行計画 vs 悪い実行計画

### ❌ 悪い例

```sql
EXPLAIN FORMAT=TREE
SELECT S.shop_name, R.reserve_name
FROM Reservations R
JOIN Shops S ON R.shop_id = S.shop_id
WHERE S.rating >= 4.5;
```

**出力:**
```
-> Inner hash join (R.shop_id = S.shop_id)  (cost=26.5 rows=20)
    -> Table scan on R  (cost=0.25 rows=10)
    -> Hash
        -> Filter: (S.rating >= 4.5)  (cost=6.25 rows=20)
            -> Table scan on S  (cost=6.25 rows=60)
```

**問題点:**
- `Table scan on S` → Shopsテーブル全件スキャン
- `Table scan on R` → Reservationsテーブル全件スキャン
- インデックス未使用

---

### ✅ 良い例（改善後）

```sql
-- インデックス追加
CREATE INDEX idx_rating ON Shops(rating);
CREATE INDEX idx_shop_id ON Reservations(shop_id);

EXPLAIN FORMAT=TREE
SELECT S.shop_name, R.reserve_name
FROM Reservations R
JOIN Shops S ON R.shop_id = S.shop_id
WHERE S.rating >= 4.5;
```

**出力:**
```
-> Nested loop inner join  (cost=2.8 rows=2)
    -> Index range scan on S using idx_rating  (cost=0.81 rows=2)
    -> Index lookup on R using idx_shop_id (shop_id=S.shop_id)  (cost=0.35 rows=1)
```

**改善点:**
- ✅ `Index range scan` → インデックス使用
- ✅ `Index lookup` → 結合でもインデックス使用
- ✅ `Nested loop` → 高速な結合アルゴリズム
- ✅ `cost` が 26.5 → 2.8（約90%削減）

---

## まとめ

### EXPLAINで見るべきポイント

**優先度順:**
1. **type** → `ALL` なら要改善
2. **key** → `NULL` ならインデックス追加
3. **rows** → 大きければ絞り込み
4. **Extra** → `Using filesort/temporary` なら要注意

### 高速なクエリの特徴

✅ `type` が `const`, `eq_ref`, `ref`, `range`
✅ `key` にインデックス名が表示
✅ `rows` が少ない
✅ `Extra` に `Using index`（カバリングインデックス）

### 遅いクエリの特徴

❌ `type = ALL`（フルテーブルスキャン）
❌ `key = NULL`（インデックス未使用）
❌ `rows` が異常に大きい
❌ `Extra` に `Using filesort; Using temporary`

---

## 参考リンク

- [knowledge/join-algorithms.md](../knowledge/join-algorithms.md) - 結合アルゴリズム詳細
- [knowledge/index-strategies.md](../knowledge/index-strategies.md) - インデックス戦略
- [knowledge/temp-fall.md](../knowledge/temp-fall.md) - TEMP落ち対策
- [tasks/diagnose-slow-query.md](./diagnose-slow-query.md) - 遅いクエリの診断フロー
- [tasks/review-query.md](./review-query.md) - SQLクエリレビューチェックリスト
