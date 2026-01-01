# ウィンドウ関数とGROUP BY

## GROUP BYの2つの機能

GROUP BY句は **「カット」** と **「集約」** の2つの機能を持つ

### カット（Cut）
母集合を部分集合（パーティション）に分割する

### 集約（Aggregation）
各部分集合を1行にまとめる

---

## GROUP BY vs PARTITION BY

| 機能 | GROUP BY | PARTITION BY |
|------|----------|--------------|
| **カット** | ✅ | ✅ |
| **集約** | ✅ | ❌ |
| **出力行数** | 減る（グループ数） | 変わらない（元のまま） |
| **使い方** | 集約関数と併用 | ウィンドウ関数と併用 |

---

## カット: 集合を部分集合に切り分ける

### 例1: 列でカット
```sql
-- 名前の頭文字でグループ化
SELECT SUBSTRING(name, 1, 1) AS initial, COUNT(*)
FROM Persons
GROUP BY SUBSTRING(name, 1, 1);
```

**結果:**
| initial | count |
|---------|-------|
| A | 3 |
| B | 2 |
| C | 5 |

### 例2: CASE式でカット（年齢階級）
```sql
SELECT
    CASE WHEN age < 20 THEN '子供'
         WHEN age BETWEEN 20 AND 69 THEN '成人'
         WHEN age >= 70 THEN '老人'
    END AS age_class,
    COUNT(*)
FROM Persons
GROUP BY
    CASE WHEN age < 20 THEN '子供'
         WHEN age BETWEEN 20 AND 69 THEN '成人'
         WHEN age >= 70 THEN '老人'
    END;
```

**結果:**
| age_class | count |
|-----------|-------|
| 子供 | 5 |
| 成人 | 15 |
| 老人 | 3 |

**ポイント:** GROUP BY句には列名だけでなく **CASE式や計算式** も書ける！

---

## GROUP BY の制約

GROUP BYで集約すると、SELECT句に書けるのは以下の3つだけ：

1. **定数**
2. **集約キー**（GROUP BY句で指定した列）
3. **集約関数**（COUNT, SUM, AVG, MAX, MIN）

```sql
-- ❌ 間違い: GROUP BY句にない列を直接SELECTできない
SELECT name, prefecture, COUNT(*)
FROM Persons
GROUP BY prefecture;
-- nameはGROUP BY句にないのでエラー

-- ✅ 正しい: 集約関数を使うか、GROUP BYに追加
SELECT prefecture, COUNT(*)
FROM Persons
GROUP BY prefecture;
```

---

## PARTITION BY: 行を減らさずにグループ内分析

PARTITION BYは **カットだけ** を行い、**集約しない**

### 基本構文
```sql
SELECT 列名,
       ウィンドウ関数 OVER (
           PARTITION BY グルーピング列
           ORDER BY ソート列
       ) AS 新しい列名
FROM テーブル名;
```

### 例: 年齢階級内でのランキング
```sql
SELECT name, age,
       CASE WHEN age < 20 THEN '子供'
            WHEN age BETWEEN 20 AND 69 THEN '成人'
            WHEN age >= 70 THEN '老人'
       END AS age_class,
       RANK() OVER (
           PARTITION BY CASE WHEN age < 20 THEN '子供'
                            WHEN age BETWEEN 20 AND 69 THEN '成人'
                            WHEN age >= 70 THEN '老人'
                       END
           ORDER BY age DESC
       ) AS age_rank_in_class
FROM Persons;
```

**結果:**
| name | age | age_class | age_rank_in_class |
|------|-----|-----------|-------------------|
| Alice | 75 | 老人 | 1 |
| Bob | 70 | 老人 | 2 |
| Carol | 65 | 成人 | 1 |
| Dave | 50 | 成人 | 2 |
| Eve | 18 | 子供 | 1 |

**ポイント:** 元の行数を保ったまま、各グループ内でのランキングを付与

---

## 主なウィンドウ関数

### 順位関数
| 関数 | 説明 |
|------|------|
| ROW_NUMBER() | 連番（重複なし: 1,2,3,...） |
| RANK() | ランキング（同順位あり、次は飛ぶ: 1,2,2,4,...） |
| DENSE_RANK() | ランキング（同順位あり、次は飛ばない: 1,2,2,3,...） |

### 集約関数（ウィンドウ版）
| 関数 | 説明 |
|------|------|
| SUM() OVER() | グループ内の累計・合計 |
| AVG() OVER() | グループ内の平均 |
| COUNT() OVER() | グループ内のカウント |
| MAX() OVER() | グループ内の最大値 |
| MIN() OVER() | グループ内の最小値 |

### アクセス関数
| 関数 | 説明 |
|------|------|
| LEAD() | 次の行の値 |
| LAG() | 前の行の値 |
| FIRST_VALUE() | 最初の行の値 |
| LAST_VALUE() | 最後の行の値 |

---

## GROUP BY vs PARTITION BY の使い分け

### GROUP BYを使う場合
- 各グループを **1行にまとめたい**
- グループごとの **集計値だけ** が必要
- レポート、ダッシュボードの集計

```sql
-- 都道府県別の人口合計（1都道府県1行）
SELECT prefecture, SUM(population)
FROM Cities
GROUP BY prefecture;
```

### PARTITION BYを使う場合
- 元の行を **保ったまま** グループ内分析
- 各行にグループ内順位を付与
- 各行にグループ内集計値を付与

```sql
-- 各都市に、都道府県内での人口順位を付与（全行残る）
SELECT city, prefecture, population,
       RANK() OVER (PARTITION BY prefecture ORDER BY population DESC) AS rank_in_prefecture
FROM Cities;
```

---

## パフォーマンス考慮事項

### 内部処理
GROUP BY / PARTITION BY の内部では **ハッシュ** または **ソート** が実行される

```
実行計画例（PostgreSQL）:
HashAggregate (cost=1.23..1.30 rows=5 width=72)
  -> Seq Scan on table
```

### リスク
- ハッシュ/ソートはワーキングメモリを消費
- メモリ不足 → **TEMP落ち** → 劇的な遅延

**参照:** [knowledge/temp-fall.md](./temp-fall.md)

### 最適化のポイント
1. GROUP BY句に不要な列を含めない
2. インデックスを活用してソートを削減
3. ワーキングメモリの設定を確認
4. CASE式を使っても実行計画は大きく変わらない（CPU演算のみ増加）

---

## 強力な組み合わせ

```
GROUP BY + CASE式 = 柔軟なパーティション定義
PARTITION BY + CASE式 = 行を減らさずにグループ内分析
```

### 例: CASE式で柔軟なグループ化
```sql
-- 売上規模でグループ化
SELECT
    CASE WHEN sales < 100000 THEN '小規模'
         WHEN sales < 1000000 THEN '中規模'
         ELSE '大規模'
    END AS sales_category,
    COUNT(*) AS店舗数,
    AVG(sales) AS平均売上
FROM Shops
GROUP BY
    CASE WHEN sales < 100000 THEN '小規模'
         WHEN sales < 1000000 THEN '中規模'
         ELSE '大規模'
    END;
```

---

## まとめ

| 概念 | 説明 |
|------|------|
| **カット** | 母集合を部分集合（パーティション）に分割 |
| **集約** | 複数行を1行にまとめる |
| **パーティション** | カットで作られた部分集合（互いに重複なし） |
| **GROUP BY** | カット + 集約（行を減らす） |
| **PARTITION BY** | カットのみ（行を保つ） |

**重要:** GROUP BY句には列名だけでなく、CASE式や計算式も使える！

---

## ウィンドウ関数でループを代替

### ループが必要な理由
手続き型プログラミングでは「前の行」「次の行」を参照するためにループを使う

```java
// Javaでの典型的なループ
for (int i = 0; i < sales.length; i++) {
    if (i > 0) {
        diff = sales[i] - sales[i-1];  // 前の行を参照
    }
}
```

SQLでは **ウィンドウ関数** がこれを代替する！

---

## LAG/LEAD: 前後の行を参照

### LAG関数（前の行を参照）

#### 基本構文
```sql
LAG(列名, オフセット, デフォルト値) OVER (
    PARTITION BY パーティション列
    ORDER BY ソート列
)
```

**パラメータ:**
- `列名`: 参照したい列
- `オフセット`: 何行前を見るか（省略時は1）
- `デフォルト値`: 前の行がない場合の値（省略時はNULL）

#### 例1: 前年比を計算
```sql
-- ❌ ぐるぐる系
for (company : companies) {
    prevYear = SELECT sale FROM Sales WHERE company = ? AND year = ? - 1;
    thisYear = SELECT sale FROM Sales WHERE company = ? AND year = ?;
    diff = thisYear - prevYear;
}

-- ✅ ガツン系（LAG関数）
SELECT company, year, sale,
       sale - LAG(sale) OVER (PARTITION BY company ORDER BY year) AS diff,
       CASE SIGN(sale - LAG(sale) OVER (PARTITION BY company ORDER BY year))
            WHEN 1  THEN '増加'
            WHEN -1 THEN '減少'
            WHEN 0  THEN '横ばい'
       END AS trend
FROM Sales;
```

**結果:**
| company | year | sale | diff | trend |
|---------|------|------|------|-------|
| A社 | 2020 | 100 | NULL | NULL |
| A社 | 2021 | 150 | 50 | 増加 |
| A社 | 2022 | 120 | -30 | 減少 |
| B社 | 2020 | 200 | NULL | NULL |
| B社 | 2021 | 250 | 50 | 増加 |

**ポイント:**
- `PARTITION BY company`: 会社ごとに分割
- `ORDER BY year`: 年でソート
- 各パーティションの最初の行はNULL

#### 例2: 2行前を参照
```sql
SELECT date, price,
       LAG(price, 1) OVER (ORDER BY date) AS prev_1day,
       LAG(price, 2) OVER (ORDER BY date) AS prev_2day,
       price - LAG(price, 2) OVER (ORDER BY date) AS diff_2day
FROM StockPrices;
```

### LEAD関数（次の行を参照）

#### 基本構文
```sql
LEAD(列名, オフセット, デフォルト値) OVER (
    PARTITION BY パーティション列
    ORDER BY ソート列
)
```

#### 例: 次の値との差分
```sql
SELECT date, temperature,
       LEAD(temperature) OVER (ORDER BY date) AS next_temp,
       LEAD(temperature) OVER (ORDER BY date) - temperature AS temp_change
FROM Weather;
```

**結果:**
| date | temperature | next_temp | temp_change |
|------|-------------|-----------|-------------|
| 2024-01-01 | 10 | 12 | 2 |
| 2024-01-02 | 12 | 8 | -4 |
| 2024-01-03 | 8 | NULL | NULL |

---

## ROW_NUMBER: 行番号を付与

### 基本構文
```sql
ROW_NUMBER() OVER (
    PARTITION BY パーティション列
    ORDER BY ソート列
)
```

#### 例1: 各グループ内での連番
```sql
SELECT company, year, sale,
       ROW_NUMBER() OVER (PARTITION BY company ORDER BY year) AS row_num
FROM Sales;
```

**結果:**
| company | year | sale | row_num |
|---------|------|------|---------|
| A社 | 2020 | 100 | 1 |
| A社 | 2021 | 150 | 2 |
| A社 | 2022 | 120 | 3 |
| B社 | 2020 | 200 | 1 |
| B社 | 2021 | 250 | 2 |

#### 例2: 最初と最後の行を特定
```sql
WITH numbered AS (
    SELECT company, year, sale,
           ROW_NUMBER() OVER (PARTITION BY company ORDER BY year) AS row_num,
           COUNT(*) OVER (PARTITION BY company) AS total_rows
    FROM Sales
)
SELECT company, year, sale,
       CASE
           WHEN row_num = 1 THEN '初年度'
           WHEN row_num = total_rows THEN '最終年度'
           ELSE '中間'
       END AS period_type
FROM numbered;
```

---

## 実践例: ぐるぐる系をガツン系に変換

### 例1: 累積売上の計算

#### ❌ ぐるぐる系
```java
cumulative = 0;
for (sale : sales) {
    cumulative += sale.amount;
    sale.cumulative = cumulative;
    updateDatabase(sale);
}
```

#### ✅ ガツン系（SUM OVER）
```sql
SELECT date, amount,
       SUM(amount) OVER (ORDER BY date) AS cumulative_amount
FROM Sales;
```

**結果:**
| date | amount | cumulative_amount |
|------|--------|-------------------|
| 2024-01-01 | 100 | 100 |
| 2024-01-02 | 200 | 300 |
| 2024-01-03 | 150 | 450 |

---

### 例2: ランキングと順位変動

#### ❌ ぐるぐる系
```java
// 今月と前月のランキングを取得
thisMonthRank = getRanking(thisMonth);
lastMonthRank = getRanking(lastMonth);

for (product : products) {
    thisRank = thisMonthRank.get(product.id);
    lastRank = lastMonthRank.get(product.id);
    rankChange = lastRank - thisRank;
}
```

#### ✅ ガツン系（RANK + LAG）
```sql
WITH monthly_ranks AS (
    SELECT product_id, month,
           RANK() OVER (PARTITION BY month ORDER BY sales DESC) AS rank
    FROM Sales
)
SELECT product_id, month, rank,
       LAG(rank) OVER (PARTITION BY product_id ORDER BY month) AS prev_rank,
       LAG(rank) OVER (PARTITION BY product_id ORDER BY month) - rank AS rank_change
FROM monthly_ranks;
```

---

### 例3: 欠損値の補完

#### ❌ ぐるぐる系
```java
lastValue = null;
for (row : data) {
    if (row.value != null) {
        lastValue = row.value;
    } else {
        row.value = lastValue;  // 前の値で補完
    }
}
```

#### ✅ ガツン系（COALESCE + LAG + 再帰）
```sql
-- MySQL 8.0+
WITH RECURSIVE filled AS (
    SELECT date, value,
           ROW_NUMBER() OVER (ORDER BY date) AS rn
    FROM Sensor
),
forward_fill AS (
    -- 最初の行
    SELECT date, value, rn, value AS filled_value
    FROM filled
    WHERE rn = 1

    UNION ALL

    -- 再帰
    SELECT f.date, f.value, f.rn,
           COALESCE(f.value, ff.filled_value) AS filled_value
    FROM filled f
    JOIN forward_fill ff ON f.rn = ff.rn + 1
)
SELECT date, value, filled_value
FROM forward_fill
ORDER BY date;
```

**シンプルな代替（最後の非NULL値で補完）:**
```sql
SELECT date, value,
       COALESCE(value,
           LAG(value) OVER (ORDER BY date),
           LAG(value, 2) OVER (ORDER BY date),
           -- ... 必要に応じて
           0  -- デフォルト値
       ) AS filled_value
FROM Sensor;
```

---

## ウィンドウ関数の組み合わせ

### CASE式 + ウィンドウ関数
```sql
-- 売上が前年比で増加した月だけ集計
SELECT company,
       SUM(CASE WHEN sale > LAG(sale) OVER (PARTITION BY company ORDER BY year)
                THEN sale
                ELSE 0
           END) AS total_increased_sales
FROM Sales
GROUP BY company;
```

### 複数のウィンドウ関数
```sql
SELECT company, year, sale,
       LAG(sale) OVER (PARTITION BY company ORDER BY year) AS prev_sale,
       LEAD(sale) OVER (PARTITION BY company ORDER BY year) AS next_sale,
       RANK() OVER (PARTITION BY year ORDER BY sale DESC) AS rank_in_year,
       AVG(sale) OVER (PARTITION BY company) AS avg_sale_company
FROM Sales;
```

---

## パフォーマンス比較

| 処理内容 | ぐるぐる系 | ガツン系 | 改善率 |
|---------|-----------|---------|--------|
| 前年比計算（1万件） | 10秒 | 0.1秒 | 100倍 |
| 累積売上（1万件） | 15秒 | 0.2秒 | 75倍 |
| ランキング（1万件） | 12秒 | 0.3秒 | 40倍 |

---

## まとめ

**ウィンドウ関数でループを代替:**
```
FOR文でループ       →  LAG/LEAD（前後の行参照）
累積計算            →  SUM OVER（累積和）
連番付与            →  ROW_NUMBER（行番号）
ランキング          →  RANK/DENSE_RANK（順位）
```

**重要な組み合わせ:**
- **CASE式 + ウィンドウ関数** = 条件付きループ処理
- **LAG + SIGN + CASE** = 増減判定
- **ROW_NUMBER + 条件** = 最初/最後の行特定

**参照:**
- [knowledge/anti-patterns.md](./anti-patterns.md#ぐるぐる系n1問題) - N+1問題の詳細

---

## サブクエリからウィンドウ関数への置き換え

> 「困難は分割するな。ウィンドウ関数で結合を消去せよ」

### 概要

サブクエリを使うと、**同じテーブルに複数回アクセス**し、結合が発生してI/Oが増加する。ウィンドウ関数を使えば、テーブルアクセスを1回に減らせる。

---

### パターン1: MIN/MAX取得 → ROW_NUMBER

#### ❌ サブクエリ結合（遅い）

```sql
-- Receiptsテーブルに2回アクセス
SELECT R1.cust_id, R1.seq, R1.price
FROM Receipts R1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq
    FROM Receipts  -- ← 1回目のアクセス
    GROUP BY cust_id
) R2
ON R1.cust_id = R2.cust_id  -- ← 2回目のアクセス（R1として）
AND R1.seq = R2.min_seq;
```

**問題:**
- テーブルアクセス2回
- 結合1回
- 実行計画変動リスク

**EXPLAIN例:**
```
-> Inner hash join  (cost=500 rows=100)
    -> Table scan on R1  (cost=200 rows=10000)  ← 1回目
    -> Hash
        -> Table scan on Receipts  (cost=200 rows=10000)  ← 2回目
```

#### ✅ ROW_NUMBER（速い）

```sql
-- Receiptsテーブルに1回だけアクセス
SELECT cust_id, seq, price
FROM (
    SELECT cust_id, seq, price,
           ROW_NUMBER() OVER (
               PARTITION BY cust_id
               ORDER BY seq
           ) AS row_seq
    FROM Receipts  -- ← 1回のアクセス
) WORK
WHERE WORK.row_seq = 1;
```

**改善点:**
- テーブルアクセス1回のみ
- 結合なし
- I/O削減

**EXPLAIN例:**
```
-> Filter: (WORK.row_seq = 1)
    -> Window aggregate
        -> Table scan on Receipts  (cost=200 rows=10000)  ← 1回のみ
```

**性能比較:**
```
サブクエリ結合: 約2倍遅い（テーブルアクセス2回）
ROW_NUMBER:    高速（テーブルアクセス1回）
```

---

### パターン2: 相関サブクエリ → ウィンドウ関数

#### ❌ 相関サブクエリ（遅い）

```sql
-- 外側の行ごとに内側のSQLを実行
SELECT cust_id, seq, price
FROM Receipts R1
WHERE seq = (
    SELECT MIN(seq)
    FROM Receipts R2
    WHERE R1.cust_id = R2.cust_id  -- 相関条件
);
```

**問題:**
- やっぱりテーブルに2回アクセス
- 外側の行ごとにループ
- 実行計画は結合とほぼ同じ

**EXPLAIN例:**
```
-> Filter: (R1.seq = (select #2))
    -> Table scan on R1  (cost=200 rows=10000)  ← 1回目
    -> Select #2  ← 外側の行ごとに実行
        -> Aggregate
            -> Table scan on R2  (cost=200 rows=10000)  ← 2回目
```

#### ✅ ウィンドウ関数（速い）

```sql
-- 同じ結果を1回のスキャンで取得
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
- 相関条件が不要
- ループなし
- テーブルアクセス1回

---

### パターン3: 集約結果の取得 → MAX/MIN OVER

#### ❌ サブクエリで集約（遅い）

```sql
-- 顧客ごとの最大購入額を全行に付与
SELECT R1.cust_id, R1.seq, R1.price,
       (SELECT MAX(price)
        FROM Receipts R2
        WHERE R2.cust_id = R1.cust_id) AS max_price
FROM Receipts R1;
```

**問題:**
- 外側の行ごとにサブクエリ実行
- テーブルに2回アクセス

#### ✅ MAX OVER（速い）

```sql
-- ウィンドウ関数で1回のスキャンで取得
SELECT cust_id, seq, price,
       MAX(price) OVER (PARTITION BY cust_id) AS max_price
FROM Receipts;
```

**改善点:**
- サブクエリ不要
- テーブルアクセス1回
- 全行に集約結果を付与

**結果:**
| cust_id | seq | price | max_price |
|---------|-----|-------|-----------|
| A | 1 | 100 | 300 |
| A | 2 | 300 | 300 |
| A | 3 | 200 | 300 |
| B | 1 | 150 | 250 |
| B | 2 | 250 | 250 |

---

### パターン4: 前後の値との比較 → LAG/LEAD

#### ❌ 自己結合（遅い）

```sql
-- 前年の売上と比較
SELECT S1.company, S1.year, S1.sale,
       S2.sale AS prev_sale,
       S1.sale - S2.sale AS diff
FROM Sales S1
LEFT JOIN Sales S2
  ON S1.company = S2.company
  AND S1.year = S2.year + 1;
```

**問題:**
- テーブルに2回アクセス
- 結合が発生

#### ✅ LAG（速い）

```sql
-- ウィンドウ関数で前年の値を参照
SELECT company, year, sale,
       LAG(sale) OVER (PARTITION BY company ORDER BY year) AS prev_sale,
       sale - LAG(sale) OVER (PARTITION BY company ORDER BY year) AS diff
FROM Sales;
```

**改善点:**
- 自己結合不要
- テーブルアクセス1回
- 前年がない場合はNULL（自然な動作）

---

### パターン5: グループ内の順位 → RANK/DENSE_RANK

#### ❌ サブクエリでカウント（遅い）

```sql
-- 各年の売上ランキング
SELECT company, year, sale,
       (SELECT COUNT(*) + 1
        FROM Sales S2
        WHERE S2.year = S1.year
          AND S2.sale > S1.sale) AS rank
FROM Sales S1;
```

**問題:**
- 外側の行ごとにサブクエリ実行
- テーブルに2回アクセス

#### ✅ RANK（速い）

```sql
-- ウィンドウ関数で順位付け
SELECT company, year, sale,
       RANK() OVER (PARTITION BY year ORDER BY sale DESC) AS rank
FROM Sales;
```

**改善点:**
- サブクエリ不要
- テーブルアクセス1回
- 同順位の処理が自動

**結果:**
| company | year | sale | rank |
|---------|------|------|------|
| B社 | 2020 | 200 | 1 |
| A社 | 2020 | 100 | 2 |
| B社 | 2021 | 250 | 1 |
| A社 | 2021 | 150 | 2 |

---

## サブクエリ vs ウィンドウ関数 比較表

| 処理内容 | サブクエリ | ウィンドウ関数 | テーブルアクセス削減 |
|---------|-----------|---------------|-------------------|
| **MIN/MAX取得** | サブクエリ結合 | ROW_NUMBER | 2回 → 1回 |
| **相関サブクエリ** | WHERE句でループ | ROW_NUMBER | 2回 → 1回 |
| **集約結果付与** | スカラーサブクエリ | MAX/MIN OVER | 2回 → 1回 |
| **前後の値参照** | 自己結合 | LAG/LEAD | 2回 → 1回 |
| **順位付け** | COUNTサブクエリ | RANK | 2回 → 1回 |

---

## 置き換えの判断フロー

```
サブクエリを使っている？
├─ NO  → OK
└─ YES → 次へ

同じテーブルに複数回アクセス？
├─ NO  → 次へ（別テーブルとの結合なら問題なし）
└─ YES → ウィンドウ関数で置き換え検討

置き換え可能なパターン？
├─ MIN/MAX取得          → ROW_NUMBER
├─ 相関サブクエリ        → ROW_NUMBER
├─ 集約結果の全行付与    → MAX/MIN/AVG OVER
├─ 前後の値との比較      → LAG/LEAD
└─ グループ内順位        → RANK/DENSE_RANK

結合前に行数を大幅に絞れる？（10倍以上）
├─ YES → サブクエリ有効（そのまま）
└─ NO  → ウィンドウ関数で置き換え
```

---

## まとめ

### サブクエリの問題点

❌ 同じテーブルに複数回アクセス → **I/O増加**
❌ 結合が発生 → 実行計画変動リスク
❌ 相関サブクエリ → ループ処理

### ウィンドウ関数の利点

✅ テーブルアクセス1回のみ
✅ 結合不要
✅ I/O最小化
✅ 実行計画が安定

### 置き換えパターン

| サブクエリパターン | ウィンドウ関数 |
|------------------|--------------|
| MIN/MAX取得 | ROW_NUMBER |
| 相関サブクエリ | ROW_NUMBER |
| 集約結果付与 | MAX/MIN/AVG OVER |
| 前後の値参照 | LAG/LEAD |
| 順位付け | RANK/DENSE_RANK |

### 例外（サブクエリが有効）

✅ 結合前に行数を大幅に絞れる場合（10倍以上削減）

**参照:**
- [knowledge/subquery-problems.md](./subquery-problems.md) - サブクエリの問題点
- [knowledge/anti-patterns.md](./anti-patterns.md#サブクエリパラノイア) - サブクエリ・パラノイア
- [tasks/review-query.md](../tasks/review-query.md#5-サブクエリ) - サブクエリチェックリスト

---

## SQLと順序──順序処理の応用パターン

> 「SQLに手続き型が復活した。集合指向 + 手続き型 のハイブリッド言語に進化」

### SQLと順序の歴史

#### 伝統的なSQL（純粋な集合指向）

```
集合理論に基づく設計:
  - テーブルの行に順序はない
  - ループを排除
  - 連番を扱う機能がなかった
  - 「何を取得するか」だけを記述（宣言型）
```

**問題点:**
- 現実のビジネスロジックは手続き的
- 順序が必要な処理（ランキング、連番、前後比較）が苦手
- アプリケーション側でループ処理が必要

#### 現在のSQL（ハイブリッド）

```
SQL:2003 でウィンドウ関数が導入:
  - 行の順序を扱える
  - 手続き型の考え方がSQLに復活
  - 集合指向 + 手続き型 の融合
```

**メリット:**
- 順序処理をSQL側で完結
- アプリケーション側のループ不要
- パフォーマンス向上（DB内で処理）

---

### ナンバリング（連番生成）

#### 基本: ROW_NUMBERで連番を振る

```sql
-- 全行に連番を振る
SELECT student_id,
       ROW_NUMBER() OVER (ORDER BY student_id) AS seq
FROM Weights;
```

**結果:**
| student_id | seq |
|------------|-----|
| A100 | 1 |
| A101 | 2 |
| A124 | 3 |
| B343 | 4 |

#### ❌ 昔の方法（相関サブクエリ）← 使うな

```sql
-- 古い方法: 遅い
SELECT student_id,
       (SELECT COUNT(*)
        FROM Weights W2
        WHERE W2.student_id <= W1.student_id) AS seq
FROM Weights W1;
```

**問題:**
- テーブルに2回アクセス
- 外側の行ごとにサブクエリ実行
- **O(N²)の計算量** → 遅い

**ROW_NUMBERとの比較:**
```
相関サブクエリ: O(N²) → 1万行で1億回比較
ROW_NUMBER:    O(N log N) → 1万行で約13万回比較（約800倍高速）
```

#### グループごとに連番を振る

```sql
-- クラスごとに1から始まる連番
SELECT class, student_id,
       ROW_NUMBER() OVER (
           PARTITION BY class
           ORDER BY student_id
       ) AS seq
FROM Weights2;
```

**結果:**
| class | student_id | seq |
|-------|------------|-----|
| 1 | 100 | 1 |  ← クラス1内で1から
| 1 | 101 | 2 |
| 1 | 102 | 3 |
| 2 | 100 | 1 |  ← クラス2内で1から
| 2 | 101 | 2 |

**活用例:**
- ページング（1ページ目、2ページ目...）
- グループ内順位
- 重複行の除去（seq = 1 の行だけ取得）

---

### ナンバリングの応用1: 中央値（メジアン）を求める

#### 問題: 中央値の定義

```
データ: [1, 3, 5, 7, 9]
中央値: 5（真ん中の値）

データ: [1, 3, 5, 7] （偶数個）
中央値: (3 + 5) / 2 = 4（真ん中2つの平均）
```

#### ❌ 集合指向的な解（自己結合）

```sql
-- 複雑で遅い（自己結合が発生）
SELECT AVG(weight)
FROM (SELECT W1.weight
      FROM Weights W1, Weights W2
      GROUP BY W1.weight
      HAVING SUM(CASE WHEN W2.weight >= W1.weight THEN 1 ELSE 0 END) >= COUNT(*)/2
         AND SUM(CASE WHEN W2.weight <= W1.weight THEN 1 ELSE 0 END) >= COUNT(*)/2
     ) TMP;
```

**問題:**
- 自己結合が発生
- 理解が困難
- 性能が悪い

#### ✅ 手続き型の解（ウィンドウ関数）

```sql
-- シンプルで速い
SELECT AVG(weight)
FROM (SELECT weight,
             ROW_NUMBER() OVER (ORDER BY weight ASC) AS hi,
             ROW_NUMBER() OVER (ORDER BY weight DESC) AS lo
      FROM Weights) TMP
WHERE hi IN (lo, lo+1, lo-1);
```

**仕組み:**
```
weight | hi | lo
-------|----|-----
1      | 1  | 5  ← 両端
3      | 2  | 4  ←
5      | 3  | 3  ← ぶつかった！中央
7      | 4  | 2  ←
9      | 5  | 1  ← 両端
```

**ロジック:**
- `hi`: 昇順で番号付け
- `lo`: 降順で番号付け
- **両端から数えてぶつかった地点が中央**
- `hi IN (lo, lo+1, lo-1)` で偶数個にも対応

---

### ROWS BETWEEN（行間比較）

#### 基本構文

```sql
関数 OVER (
    ORDER BY ソート順
    ROWS BETWEEN 開始位置 AND 終了位置
)
```

**位置指定:**
- `CURRENT ROW`: 現在行
- `1 PRECEDING`: 1行前
- `1 FOLLOWING`: 1行後
- `UNBOUNDED PRECEDING`: 先頭から
- `UNBOUNDED FOLLOWING`: 最後まで

#### 例: 1行後の値を取得

```sql
SELECT num,
       MAX(num) OVER (
           ORDER BY num
           ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING
       ) AS next_num
FROM Numbers;
```

**結果:**
| num | next_num |
|-----|----------|
| 1 | 3 |
| 3 | 4 |
| 4 | 7 |
| 7 | NULL |

**用途:**
- 欠番検出（`next_num - num > 1` なら欠番あり）
- 連続判定

#### 例: 移動平均（3行平均）

```sql
SELECT date, sales,
       AVG(sales) OVER (
           ORDER BY date
           ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
       ) AS moving_avg_3
FROM DailySales;
```

**結果:**
| date | sales | moving_avg_3 |
|------|-------|--------------|
| 2024-01-01 | 100 | (100+150)/2 = 125 |
| 2024-01-02 | 150 | (100+150+200)/3 = 150 |
| 2024-01-03 | 200 | (150+200+180)/3 = 176.7 |
| 2024-01-04 | 180 | (200+180)/2 = 190 |

---

### ナンバリングの応用2: 欠番（断絶区間）を求める

#### 問題

```
テーブル: [1, 3, 4, 7, 8, 9, 12]
欲しい結果: 欠番のシーケンス
  2〜2, 5〜6, 10〜11
```

#### 手続き型の解

```sql
SELECT num + 1 AS gap_start,
       (num + diff - 1) AS gap_end
FROM (SELECT num,
             MAX(num) OVER (
                 ORDER BY num
                 ROWS BETWEEN 1 FOLLOWING AND 1 FOLLOWING
             ) - num AS diff
      FROM Numbers) TMP
WHERE diff <> 1;
```

**仕組み:**
```
num | next_num | diff | gap_start | gap_end
----|----------|------|-----------|--------
1   | 3        | 2    | 2         | 2      ← 2〜2が欠番
3   | 4        | 1    | -         | -      （連続）
4   | 7        | 3    | 5         | 6      ← 5〜6が欠番
7   | 8        | 1    | -         | -      （連続）
8   | 9        | 1    | -         | -      （連続）
9   | 12       | 3    | 10        | 11     ← 10〜11が欠番
```

**ロジック:**
- 「カレント行と1行後の差が1でなければ欠番」
- `gap_start = num + 1`（欠番の開始）
- `gap_end = num + diff - 1`（欠番の終了）

---

### ナンバリングの応用3: 連続するシーケンスを求める

#### 問題

```
テーブル: [1, 3, 4, 7, 8, 9, 12]
欲しい結果: 連続する塊
  1〜1, 3〜4, 7〜9, 12〜12
```

#### 手続き型の解（エレガント）

```sql
SELECT MIN(num) AS start_num,
       MAX(num) AS end_num
FROM (SELECT num,
             num - ROW_NUMBER() OVER (ORDER BY num) AS group_id
      FROM Numbers) RankedNumbers
GROUP BY group_id;
```

**仕組み:**
```
num | ROW_NUMBER | group_id (差分)
----|------------|----------------
1   | 1          | 0   ← 同じgroup_idは
3   | 2          | 1   ← 連続する塊
4   | 3          | 1   ←
7   | 4          | 3   ← 新しい塊
8   | 5          | 3   ←
9   | 6          | 3   ←
12  | 7          | 5   ← また新しい塊
```

**ロジック:**
- **連続する数値は `num - ROW_NUMBER()` が同じ値になる**
- group_idでGROUP BYすると連続塊ごとに集約
- MIN/MAXで開始・終了を取得

**応用:**
- 在庫の連続欠品期間
- ログイン連続日数
- 連続稼働時間

---

## まとめ

### SQLの進化

```
伝統的SQL:  集合指向のみ
現在のSQL:  集合指向 + 手続き型（ハイブリッド）
```

### ウィンドウ関数の順序処理

| 処理 | 関数 | 用途 |
|------|------|------|
| **連番生成** | ROW_NUMBER | ページング、重複除去 |
| **順位付け** | RANK/DENSE_RANK | ランキング |
| **前後参照** | LAG/LEAD | 前年比、増減判定 |
| **行間比較** | ROWS BETWEEN | 欠番検出、移動平均 |
| **中央値** | ROW_NUMBER(昇順/降順) | 統計処理 |
| **連続塊** | num - ROW_NUMBER | 連続期間検出 |

### メリット

✅ 自己結合を消去できる
✅ テーブルアクセス1回で済む
✅ 実行計画がシンプルで安定
✅ アプリケーション側のループ不要
✅ パフォーマンス向上

### 相関サブクエリとの比較

| 処理 | 相関サブクエリ | ROW_NUMBER |
|------|--------------|------------|
| テーブルアクセス | 2回 | 1回 |
| 計算量 | O(N²) | O(N log N) |
| 可読性 | 低い | 高い |
| 性能 | 遅い | 速い |

**参照:**
- [examples/common-patterns.md](../examples/common-patterns.md#ウィンドウ関数による順序処理パターン) - 欠番検出、連続シーケンス検出
- [knowledge/anti-patterns.md](./anti-patterns.md#シーケンスidentity列の乱用) - シーケンス/IDENTITYの問題点
