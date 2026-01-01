# TEMP落ち

## TEMP落ちとは

ワーキングメモリ（作業用メモリ）が不足して、一時データがディスクに書き出される現象

```
メモリ内処理（高速） → ディスク書き出し（激遅）
```

**影響:** クエリパフォーマンスが劇的に悪化（数秒 → 数分〜数時間）

---

## TEMP落ちが発生する処理

### 1. ハッシュ処理
- **GROUP BY** によるハッシュ集約
- **ハッシュJOIN**
- **IN/EXISTSサブクエリ** のハッシュテーブル

### 2. ソート処理
- **ORDER BY**
- **GROUP BY** によるソート集約
- **DISTINCT**
- **UNION**（重複除去のソート）
- **ウィンドウ関数** のソート

### 3. その他
- **マテリアライズド一時テーブル**
- **再帰クエリ**

---

## GROUP BY / ウィンドウ関数の内部動作

### ハッシュ集約
```
実行計画例（PostgreSQL）:
HashAggregate (cost=1.23..1.30 rows=5 width=72)
  -> Seq Scan on NonAggTbl
```

**特徴:**
- メモリ内にハッシュテーブルを構築
- O(1)で高速アクセス
- **メモリ使用量が大きい**
- グループ数が多いとメモリ不足 → TEMP落ち

### ソート集約
```
実行計画例（PostgreSQL）:
GroupAggregate (cost=1.41..1.48 rows=5 width=72)
  -> Sort (cost=1.41..1.42 rows=5 width=72)
        Sort Key: id
        -> Seq Scan on NonAggTbl
```

**特徴:**
- 最初にソート、次に集約
- ソート時にメモリを消費
- **データ量が多いとメモリ不足 → TEMP落ち**

---

## TEMP落ちの検出

### 実行計画で確認

#### PostgreSQL
```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
```

出力例:
```
Sort Method: external merge  Disk: 102400kB
```
→ `external merge`や`Disk:`が出たらTEMP落ち

#### MySQL
```sql
EXPLAIN FORMAT=TREE SELECT ...;
```

出力例:
```
-> Sort: ... (Using filesort)
```
→ `Using filesort`や`Using temporary`が出たら要注意

### スロークエリログで確認

```
# Query_time: 120.345
# Tmp_tables: 1
# Tmp_disk_tables: 1  ← ディスク上の一時テーブル使用
```

---

## TEMP落ちの原因

| 原因 | 説明 |
|------|------|
| **データ量が多い** | GROUP BYやソート対象のデータが大きい |
| **グループ数が多い** | GROUP BYのキーのカーディナリティが高い |
| **ワーキングメモリ不足** | work_mem（PostgreSQL）や sort_buffer_size（MySQL）が小さい |
| **複雑なクエリ** | 複数のGROUP BY、ウィンドウ関数、ソートが重複 |

---

## TEMP落ちの対策

### 1. ワーキングメモリを増やす

#### PostgreSQL
```sql
-- セッション単位で設定
SET work_mem = '256MB';

-- クエリ単位で設定
SET LOCAL work_mem = '512MB';
```

#### MySQL
```sql
-- セッション単位で設定
SET SESSION sort_buffer_size = 268435456;  -- 256MB
```

**注意:** むやみに大きくしすぎると、複数セッションで同時実行時にメモリ不足に

### 2. データを絞り込む

```sql
-- ❌ 全データをGROUP BY
SELECT prefecture, COUNT(*)
FROM Population
GROUP BY prefecture;

-- ✅ WHERE句で事前に絞り込む
SELECT prefecture, COUNT(*)
FROM Population
WHERE age >= 20  -- 必要なデータだけ
GROUP BY prefecture;
```

### 3. インデックスを活用してソートを削減

```sql
-- id列にインデックスがあれば、ソートが不要に
CREATE INDEX idx_id ON NonAggTbl(id);

SELECT id, MAX(data_1)
FROM NonAggTbl
GROUP BY id;
```

**実行計画:**
```
-- インデックスなし
Sort -> Table scan

-- インデックスあり（ソート不要）
Index scan
```

### 4. GROUP BY句の列を減らす

```sql
-- ❌ 不要な列を含める（グループ数増加）
SELECT name, prefecture, age, COUNT(*)
FROM Population
GROUP BY name, prefecture, age;

-- ✅ 必要最小限の列だけ
SELECT prefecture, COUNT(*)
FROM Population
GROUP BY prefecture;
```

### 5. 段階的に処理する

```sql
-- ❌ 一度に大量データを処理
SELECT prefecture, age_class, COUNT(*)
FROM Population
GROUP BY prefecture, age_class;

-- ✅ 段階的に処理（CTEやサブクエリで中間結果を作る）
WITH AgeClass AS (
    SELECT prefecture,
           CASE WHEN age < 20 THEN '子供'
                WHEN age < 70 THEN '成人'
                ELSE '老人'
           END AS age_class
    FROM Population
    WHERE prefecture IN ('東京', '大阪')  -- 絞り込み
)
SELECT prefecture, age_class, COUNT(*)
FROM AgeClass
GROUP BY prefecture, age_class;
```

### 6. パーティショニング

```sql
-- テーブルを年度でパーティション分割
CREATE TABLE Sales (
    id INT,
    sale_date DATE,
    amount DECIMAL
) PARTITION BY RANGE (YEAR(sale_date)) (
    PARTITION p2022 VALUES LESS THAN (2023),
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025)
);

-- 特定のパーティションだけスキャン
SELECT SUM(amount)
FROM Sales
WHERE sale_date >= '2023-01-01' AND sale_date < '2024-01-01'
GROUP BY MONTH(sale_date);
```

---

## CASE式とTEMP落ち

### CASE式によるパフォーマンス影響

```sql
SELECT
    CASE WHEN age < 20 THEN '子供'
         WHEN age < 70 THEN '成人'
         ELSE '老人'
    END AS age_class,
    COUNT(*)
FROM Population
GROUP BY
    CASE WHEN age < 20 THEN '子供'
         WHEN age < 70 THEN '成人'
         ELSE '老人'
    END;
```

**影響:**
- CASE式自体は **CPU演算のみ**（I/Oには影響なし）
- 実行計画は大きく変わらない
- **TEMP落ちリスクは変わらない**
- むしろグループ数を減らせるのでメモリ効率が良い場合も

---

## モニタリング

### PostgreSQL
```sql
-- 現在のwork_mem設定確認
SHOW work_mem;

-- 実行中のクエリでTEMP使用を確認
SELECT pid, query, temp_files, temp_bytes
FROM pg_stat_activity
WHERE temp_files > 0;
```

### MySQL
```sql
-- 現在の設定確認
SHOW VARIABLES LIKE 'sort_buffer_size';
SHOW VARIABLES LIKE 'tmp_table_size';

-- 一時テーブル使用状況
SHOW STATUS LIKE 'Created_tmp%';
```

---

## まとめ

| 項目 | 説明 |
|------|------|
| **TEMP落ちとは** | ワーキングメモリ不足でディスク書き出し |
| **発生する処理** | GROUP BY、ORDER BY、ウィンドウ関数、UNION |
| **影響** | パフォーマンスが劇的に悪化 |
| **主な原因** | データ量、グループ数、メモリ不足 |
| **対策** | メモリ増、絞り込み、インデックス、段階的処理 |

**重要:** CASE式は実行計画を大きく変えないが、グループ数を減らせるのでメモリ効率が良くなる場合がある
