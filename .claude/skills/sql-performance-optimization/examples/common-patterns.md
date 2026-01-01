# よくあるパターン

## CASE式 + 集約関数のパターン

### パターン1: 条件付き集計（SUM + CASE）

#### 用途
条件に応じた値を集計する

#### 基本形
```sql
SELECT
    SUM(CASE WHEN 条件1 THEN 列名 ELSE 0 END) AS 集計1,
    SUM(CASE WHEN 条件2 THEN 列名 ELSE 0 END) AS 集計2
FROM テーブル名;
```

#### 実例: 性別ごとの人口集計
```sql
SELECT prefecture,
       SUM(CASE WHEN sex = '1' THEN pop ELSE 0 END) AS pop_men,
       SUM(CASE WHEN sex = '2' THEN pop ELSE 0 END) AS pop_wom
FROM Population
GROUP BY prefecture;
```

#### 応用: 年代別の売上集計
```sql
SELECT product_id,
       SUM(CASE WHEN age < 20 THEN amount ELSE 0 END) AS sales_teen,
       SUM(CASE WHEN age BETWEEN 20 AND 39 THEN amount ELSE 0 END) AS sales_20s_30s,
       SUM(CASE WHEN age >= 40 THEN amount ELSE 0 END) AS sales_40plus
FROM Sales
GROUP BY product_id;
```

---

### パターン2: 条件付きカウント（COUNT + CASE）

#### 基本形
```sql
SELECT
    COUNT(CASE WHEN 条件1 THEN 1 END) AS カウント1,
    COUNT(CASE WHEN 条件2 THEN 1 END) AS カウント2
FROM テーブル名;
```

**注意:** COUNTはNULL以外をカウントするため、ELSE句は不要

#### 実例: ステータス別の注文数
```sql
SELECT customer_id,
       COUNT(CASE WHEN status = 'completed' THEN 1 END) AS completed_count,
       COUNT(CASE WHEN status = 'pending' THEN 1 END) AS pending_count,
       COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS cancelled_count
FROM Orders
GROUP BY customer_id;
```

#### 応用: 条件を満たすレコード数と割合
```sql
SELECT
    COUNT(*) AS total,
    COUNT(CASE WHEN score >= 80 THEN 1 END) AS high_score_count,
    ROUND(COUNT(CASE WHEN score >= 80 THEN 1 END) * 100.0 / COUNT(*), 2) AS high_score_rate
FROM Exams;
```

---

### パターン3: 条件付き平均（AVG + CASE）

#### 基本形
```sql
SELECT
    AVG(CASE WHEN 条件1 THEN 列名 END) AS 平均1,
    AVG(CASE WHEN 条件2 THEN 列名 END) AS 平均2
FROM テーブル名;
```

**注意:** AVGはNULLを除外するため、ELSE句は不要（または明示的にELSE NULL）

#### 実例: 性別ごとの平均年齢
```sql
SELECT department,
       AVG(CASE WHEN sex = 'M' THEN age END) AS avg_age_men,
       AVG(CASE WHEN sex = 'F' THEN age END) AS avg_age_women
FROM Employees
GROUP BY department;
```

---

### パターン4: 列の値による分岐（SELECT句でのCASE）

#### 基本形
```sql
SELECT
    CASE WHEN 条件1 THEN 値1
         WHEN 条件2 THEN 値2
         ELSE デフォルト値
    END AS 新しい列名
FROM テーブル名;
```

#### 実例: 年度による価格列の切り替え
```sql
SELECT item_name, year,
       CASE WHEN year <= 2001 THEN price_tax_ex
            WHEN year >= 2002 THEN price_tax_in
       END AS price
FROM Items;
```

#### 応用: スコアによるランク付け
```sql
SELECT student_name, score,
       CASE WHEN score >= 90 THEN 'A'
            WHEN score >= 80 THEN 'B'
            WHEN score >= 70 THEN 'C'
            WHEN score >= 60 THEN 'D'
            ELSE 'F'
       END AS grade
FROM Exams;
```

---

### パターン5: MAX/MIN + CASE（条件付き最大/最小）

#### 基本形
```sql
SELECT
    MAX(CASE WHEN 条件1 THEN 列名 END) AS 最大1,
    MIN(CASE WHEN 条件2 THEN 列名 END) AS 最小2
FROM テーブル名;
```

#### 実例: 商品カテゴリ別の最高価格
```sql
SELECT
    MAX(CASE WHEN category = 'electronics' THEN price END) AS max_electronics,
    MAX(CASE WHEN category = 'books' THEN price END) AS max_books,
    MAX(CASE WHEN category = 'clothing' THEN price END) AS max_clothing
FROM Products;
```

---

### パターン6: CASE式のネスト（複雑な条件分岐）

#### 基本形
```sql
SELECT
    CASE
        WHEN 条件1 THEN
            CASE WHEN 条件1-1 THEN 値1-1
                 ELSE 値1-2
            END
        WHEN 条件2 THEN 値2
        ELSE デフォルト値
    END AS 新しい列名
FROM テーブル名;
```

#### 実例: 地域と売上による配送方法の決定
```sql
SELECT order_id, region, amount,
       CASE
           WHEN region = 'Tokyo' THEN
               CASE WHEN amount >= 10000 THEN '当日配送'
                    ELSE '翌日配送'
               END
           WHEN region IN ('Osaka', 'Kyoto') THEN
               CASE WHEN amount >= 15000 THEN '翌日配送'
                    ELSE '2-3日配送'
               END
           ELSE '通常配送'
       END AS delivery_method
FROM Orders;
```

---

## パターン選択のガイドライン

| やりたいこと | 使うパターン | ELSE句 |
|------------|------------|--------|
| 条件付き合計 | SUM + CASE | ELSE 0（必須） |
| 条件付き件数 | COUNT + CASE | 不要（NULLを除外） |
| 条件付き平均 | AVG + CASE | 不要（NULLを除外） |
| 条件付き最大/最小 | MAX/MIN + CASE | 不要（NULLを除外） |
| 列の値の切り替え | CASE WHEN | 必要に応じて |

---

## よくある間違い

### ❌ 間違い1: COUNTで ELSE 0 を使う
```sql
-- これは動くが、意図と異なる結果になる
COUNT(CASE WHEN condition THEN 1 ELSE 0 END)
-- COUNTは0もカウントしてしまう！
```

### ✅ 正しい方法
```sql
-- ELSE句を省略してNULLにする
COUNT(CASE WHEN condition THEN 1 END)
```

---

### ❌ 間違い2: SUMで ELSE句を省略
```sql
-- NULLが含まれ、意図しない結果になる
SUM(CASE WHEN condition THEN amount END)
```

### ✅ 正しい方法
```sql
-- 明示的に ELSE 0 を指定
SUM(CASE WHEN condition THEN amount ELSE 0 END)
```

---

### ❌ 間違い3: CASE式の外でNULL処理
```sql
-- 冗長な書き方
COALESCE(SUM(CASE WHEN condition THEN amount END), 0)
```

### ✅ 正しい方法
```sql
-- CASE式内で処理
SUM(CASE WHEN condition THEN amount ELSE 0 END)
```

---

## まとめ

**CASE式 + 集約関数の利点:**
1. テーブルスキャンが1回で済む
2. UNIONを使うより高速
3. 可読性が高い
4. メンテナンスしやすい

**覚えておくべきルール:**
- `SUM + CASE`: ELSE 0 が必要
- `COUNT + CASE`: ELSE句不要（NULLを除外）
- `AVG/MAX/MIN + CASE`: ELSE句不要（NULLを除外）

---

## 非集約テーブル → 集約テーブル変換

### パターン7: 行持ちテーブルを列持ちテーブルに変換

#### 用途
1人のデータが複数行に分散しているテーブルを、1人1行にまとめる

#### Before（非集約テーブル）
| id | data_type | data_1 | data_2 | data_3 | data_4 | data_5 | data_6 |
|----|-----------|--------|--------|--------|--------|--------|--------|
| Jim | A | 100 | 10 | NULL | NULL | NULL | NULL |
| Jim | B | NULL | NULL | 167 | 77 | 90 | NULL |
| Jim | C | NULL | NULL | NULL | NULL | NULL | 457 |

**問題点:**
- 1人が3行に分散
- 横に並べたい

#### After（集約テーブル）
| id | data_1 | data_2 | data_3 | data_4 | data_5 | data_6 |
|----|--------|--------|--------|--------|--------|--------|
| Jim | 100 | 10 | 167 | 77 | 90 | 457 |

**メリット:**
- 1人1行
- 見やすい
- アプリケーションでの処理が簡単

#### 基本形: CASE式 + GROUP BY + MAX
```sql
SELECT id,
       MAX(CASE WHEN data_type = 'A' THEN data_1 END) AS data_1,
       MAX(CASE WHEN data_type = 'A' THEN data_2 END) AS data_2,
       MAX(CASE WHEN data_type = 'B' THEN data_3 END) AS data_3,
       MAX(CASE WHEN data_type = 'B' THEN data_4 END) AS data_4,
       MAX(CASE WHEN data_type = 'B' THEN data_5 END) AS data_5,
       MAX(CASE WHEN data_type = 'C' THEN data_6 END) AS data_6
FROM NonAggTbl
GROUP BY id;
```

#### なぜMAXを使うのか？

**各グループ内のデータ:**
```
id=Jimのグループ:
  CASE WHEN data_type = 'A' THEN data_1 END → [100, NULL, NULL]
  CASE WHEN data_type = 'A' THEN data_2 END → [10, NULL, NULL]
  ...
```

**MAX関数の役割:**
- NULLを除外して残った値を取り出す
- `MAX([100, NULL, NULL])` → `100`
- `MAX([10, NULL, NULL])` → `10`

**注意:** 値が1つしかない前提（複数あるとMAXが適用される）

#### GROUP BYの制約を理解する

GROUP BYで集約すると、SELECT句に書けるのは：
1. **定数**
2. **集約キー**（GROUP BY句で指定した列）
3. **集約関数**（COUNT, SUM, AVG, MAX, MIN）

```sql
-- ❌ 間違い: 集約関数なしでdata_1を直接SELECT
SELECT id, data_1  -- data_1はGROUP BY句にない
FROM NonAggTbl
GROUP BY id;

-- ✅ 正しい: 集約関数を使う
SELECT id, MAX(data_1)
FROM NonAggTbl
GROUP BY id;
```

#### 応用: 複数の条件で列を切り替え

```sql
-- テストの得点を科目別に列で表示
SELECT student_id,
       MAX(CASE WHEN subject = '数学' THEN score END) AS math_score,
       MAX(CASE WHEN subject = '英語' THEN score END) AS english_score,
       MAX(CASE WHEN subject = '国語' THEN score END) AS japanese_score
FROM TestScores
GROUP BY student_id;
```

**Before:**
| student_id | subject | score |
|------------|---------|-------|
| 1 | 数学 | 85 |
| 1 | 英語 | 90 |
| 1 | 国語 | 75 |
| 2 | 数学 | 70 |
| 2 | 英語 | 80 |
| 2 | 国語 | 65 |

**After:**
| student_id | math_score | english_score | japanese_score |
|------------|------------|---------------|----------------|
| 1 | 85 | 90 | 75 |
| 2 | 70 | 80 | 65 |

---

## GROUP BY + CASE式でカット（パーティション分割）

### パターン8: CASE式で柔軟なグループ化

#### 基本形
```sql
SELECT
    CASE WHEN 条件1 THEN 'グループ1'
         WHEN 条件2 THEN 'グループ2'
         ELSE 'その他'
    END AS group_name,
    集約関数(列名)
FROM テーブル名
GROUP BY
    CASE WHEN 条件1 THEN 'グループ1'
         WHEN 条件2 THEN 'グループ2'
         ELSE 'その他'
    END;
```

**ポイント:** GROUP BY句には列名だけでなく、**CASE式や計算式**も書ける！

#### 例1: 年齢階級でグループ化
```sql
SELECT
    CASE WHEN age < 20 THEN '子供'
         WHEN age BETWEEN 20 AND 69 THEN '成人'
         WHEN age >= 70 THEN '老人'
    END AS age_class,
    COUNT(*) AS人数,
    AVG(age) AS平均年齢
FROM Persons
GROUP BY
    CASE WHEN age < 20 THEN '子供'
         WHEN age BETWEEN 20 AND 69 THEN '成人'
         WHEN age >= 70 THEN '老人'
    END;
```

**結果:**
| age_class | 人数 | 平均年齢 |
|-----------|------|----------|
| 子供 | 5 | 15.2 |
| 成人 | 15 | 45.3 |
| 老人 | 3 | 75.7 |

#### 例2: 売上規模でグループ化
```sql
SELECT
    CASE WHEN sales < 100000 THEN '小規模'
         WHEN sales < 1000000 THEN '中規模'
         ELSE '大規模'
    END AS sales_category,
    COUNT(*) AS店舗数,
    AVG(sales) AS平均売上,
    SUM(sales) AS合計売上
FROM Shops
GROUP BY
    CASE WHEN sales < 100000 THEN '小規模'
         WHEN sales < 1000000 THEN '中規模'
         ELSE '大規模'
    END;
```

#### 例3: 時間帯でグループ化
```sql
SELECT
    CASE WHEN HOUR(access_time) < 6 THEN '深夜'
         WHEN HOUR(access_time) < 12 THEN '午前'
         WHEN HOUR(access_time) < 18 THEN '午後'
         ELSE '夜間'
    END AS time_period,
    COUNT(*) ASアクセス数
FROM AccessLogs
GROUP BY
    CASE WHEN HOUR(access_time) < 6 THEN '深夜'
         WHEN HOUR(access_time) < 12 THEN '午前'
         WHEN HOUR(access_time) < 18 THEN '午後'
         ELSE '夜間'
    END;
```

---

## まとめ（更新版）

**CASE式 + 集約関数の利点:**
1. テーブルスキャンが1回で済む
2. UNIONを使うより高速
3. 可読性が高い
4. メンテナンスしやすい
5. 柔軟なグループ化が可能

**主要パターン:**
1. SUM + CASE: 条件付き集計
2. COUNT + CASE: 条件付きカウント
3. AVG + CASE: 条件付き平均
4. MAX/MIN + CASE: 条件付き最大/最小
5. CASE式のネスト: 複雑な条件分岐
6. **MAX + CASE + GROUP BY: 行持ち→列持ち変換**
7. **GROUP BY + CASE式: 柔軟なパーティション分割**

**覚えておくべきルール:**
- `SUM + CASE`: ELSE 0 が必要
- `COUNT + CASE`: ELSE句不要（NULLを除外）
- `AVG/MAX/MIN + CASE`: ELSE句不要（NULLを除外）
- GROUP BY句には列名だけでなく、**CASE式や計算式**も書ける

---

## ウィンドウ関数による順序処理パターン

> 「連続する数値は `num - ROW_NUMBER()` が同じ値になる」

### パターン9: 欠番（断絶区間）を検出

#### 用途
テーブル内の連番の欠けている部分を検出する

#### 基本形
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

#### 実例: 在庫番号の欠番検出

```sql
-- テーブル: [1, 3, 4, 7, 8, 9, 12]
-- 欲しい結果: 欠番のシーケンス
--   2〜2, 5〜6, 10〜11

SELECT stock_num + 1 AS gap_start,
       stock_num + (next_num - stock_num - 1) AS gap_end
FROM (SELECT stock_num,
             LEAD(stock_num) OVER (ORDER BY stock_num) AS next_num
      FROM StockNumbers) TMP
WHERE next_num - stock_num > 1;
```

**仕組み:**
| stock_num | next_num | diff | gap_start | gap_end |
|-----------|----------|------|-----------|---------|
| 1 | 3 | 2 | 2 | 2 | ← 2〜2が欠番
| 3 | 4 | 1 | - | - | （連続）
| 4 | 7 | 3 | 5 | 6 | ← 5〜6が欠番
| 7 | 8 | 1 | - | - | （連続）
| 8 | 9 | 1 | - | - | （連続）
| 9 | 12 | 3 | 10 | 11 | ← 10〜11が欠番

**ロジック:**
- LEAD関数で次の値を取得
- 差が1より大きければ欠番あり
- `gap_start = num + 1`（欠番の開始）
- `gap_end = next_num - 1`（欠番の終了）

#### 応用: 座席番号の空き検出

```sql
-- 予約済み座席から空いている座席範囲を検出
SELECT seat_num + 1 AS available_start,
       next_seat - 1 AS available_end,
       (next_seat - seat_num - 1) AS available_count
FROM (SELECT seat_num,
             LEAD(seat_num) OVER (ORDER BY seat_num) AS next_seat
      FROM ReservedSeats) TMP
WHERE next_seat - seat_num > 1;
```

---

### パターン10: 連続するシーケンスを求める

#### 用途
連続する値をグループ化して、連続する塊（開始〜終了）を取得する

#### 基本形（エレガント）
```sql
SELECT MIN(num) AS start_num,
       MAX(num) AS end_num,
       COUNT(*) AS count
FROM (SELECT num,
             num - ROW_NUMBER() OVER (ORDER BY num) AS group_id
      FROM Numbers) RankedNumbers
GROUP BY group_id;
```

#### 実例: ログイン連続日数

```sql
-- テーブル: [1, 3, 4, 7, 8, 9, 12]
-- 欲しい結果: 連続する塊
--   1〜1 (1日), 3〜4 (2日), 7〜9 (3日), 12〜12 (1日)

SELECT MIN(login_date) AS streak_start,
       MAX(login_date) AS streak_end,
       COUNT(*) AS consecutive_days
FROM (SELECT login_date,
             DATE_SUB(login_date, INTERVAL ROW_NUMBER() OVER (ORDER BY login_date) DAY) AS group_id
      FROM LoginLog) RankedLogins
GROUP BY group_id;
```

**仕組み:**
| num | ROW_NUMBER | group_id (差分) |
|-----|------------|-----------------|
| 1 | 1 | 0 | ← 同じgroup_idは
| 3 | 2 | 1 | ← 連続する塊
| 4 | 3 | 1 | ←
| 7 | 4 | 3 | ← 新しい塊
| 8 | 5 | 3 | ←
| 9 | 6 | 3 | ←
| 12 | 7 | 5 | ← また新しい塊

**ロジック:**
- **連続する数値は `num - ROW_NUMBER()` が同じ値になる**
- group_idでGROUP BYすると連続塊ごとに集約
- MIN/MAXで開始・終了を取得

#### 応用: 在庫の連続欠品期間

```sql
-- 欠品日の連続期間を検出
SELECT MIN(out_of_stock_date) AS shortage_start,
       MAX(out_of_stock_date) AS shortage_end,
       DATEDIFF(MAX(out_of_stock_date), MIN(out_of_stock_date)) + 1 AS days
FROM (SELECT out_of_stock_date,
             DATE_SUB(out_of_stock_date,
                      INTERVAL ROW_NUMBER() OVER (ORDER BY out_of_stock_date) DAY
             ) AS group_id
      FROM StockStatus
      WHERE status = 'OUT_OF_STOCK') Grouped
GROUP BY group_id;
```

---

### パターン11: 中央値（メジアン）を求める

#### 用途
データの中央値を取得する（統計処理）

#### 基本形
```sql
-- 両端から数えてぶつかった地点が中央
SELECT AVG(value)
FROM (SELECT value,
             ROW_NUMBER() OVER (ORDER BY value ASC) AS hi,
             ROW_NUMBER() OVER (ORDER BY value DESC) AS lo
      FROM Measurements) TMP
WHERE hi IN (lo, lo+1, lo-1);
```

#### 実例: 売上の中央値

```sql
-- データ: [100, 150, 200, 250, 300]
-- 中央値: 200

SELECT AVG(sales)
FROM (SELECT sales,
             ROW_NUMBER() OVER (ORDER BY sales ASC) AS ascending_rank,
             ROW_NUMBER() OVER (ORDER BY sales DESC) AS descending_rank
      FROM DailySales) Ranked
WHERE ascending_rank IN (descending_rank, descending_rank + 1, descending_rank - 1);
```

**仕組み:**
| sales | hi (昇順) | lo (降順) |
|-------|-----------|-----------|
| 100 | 1 | 5 | ← 両端
| 150 | 2 | 4 | ←
| 200 | 3 | 3 | ← ぶつかった！中央
| 250 | 4 | 2 | ←
| 300 | 5 | 1 | ← 両端

**ロジック:**
- `hi`: 昇順で番号付け
- `lo`: 降順で番号付け
- **両端から数えてぶつかった地点が中央**
- `hi IN (lo, lo+1, lo-1)` で偶数個にも対応

#### 偶数個の場合

**データ: [100, 150, 200, 250]**
| sales | hi | lo | 条件判定 |
|-------|----|----|---------|
| 100 | 1 | 4 | - |
| 150 | 2 | 3 | ✅ (hi = lo+1) |
| 200 | 3 | 2 | ✅ (hi = lo-1) |
| 250 | 4 | 1 | - |

**中央値:** AVG(150, 200) = 175

---

### パターン12: グループ内順位付け

#### 用途
カテゴリ別のランキング、売上TOP3など

#### 基本形
```sql
SELECT category, product_name, sales,
       ROW_NUMBER() OVER (PARTITION BY category ORDER BY sales DESC) AS rank
FROM Products;
```

#### 実例: カテゴリ別TOP3商品

```sql
SELECT *
FROM (SELECT category, product_name, sales,
             ROW_NUMBER() OVER (
                 PARTITION BY category
                 ORDER BY sales DESC
             ) AS rank
      FROM Products) Ranked
WHERE rank <= 3;
```

**結果:**
| category | product_name | sales | rank |
|----------|--------------|-------|------|
| 電化製品 | テレビ | 100000 | 1 |
| 電化製品 | 冷蔵庫 | 80000 | 2 |
| 電化製品 | 洗濯機 | 60000 | 3 |
| 食品 | お米 | 50000 | 1 |
| 食品 | 肉 | 40000 | 2 |
| 食品 | 魚 | 30000 | 3 |

#### 応用: 各月の売上TOP1

```sql
SELECT *
FROM (SELECT DATE_FORMAT(sale_date, '%Y-%m') AS month,
             product_name, sales,
             ROW_NUMBER() OVER (
                 PARTITION BY DATE_FORMAT(sale_date, '%Y-%m')
                 ORDER BY sales DESC
             ) AS rank
      FROM DailySales) Ranked
WHERE rank = 1;
```

---

## まとめ（順序処理パターン）

### ウィンドウ関数の順序処理

| パターン | 用途 | 主要関数 |
|---------|------|---------|
| **欠番検出** | 連番の欠けている部分を検出 | LEAD/LAG, ROWS BETWEEN |
| **連続シーケンス** | 連続する塊を検出 | `num - ROW_NUMBER` |
| **中央値** | 統計処理（メジアン） | ROW_NUMBER(昇順/降順) |
| **グループ内順位** | カテゴリ別ランキング | PARTITION BY + ORDER BY |

### キーテクニック

**連続塊の検出:**
```sql
num - ROW_NUMBER() OVER (ORDER BY num) AS group_id
```
→ **連続する数値は同じgroup_idになる**

**中央値の取得:**
```sql
ROW_NUMBER() OVER (ORDER BY value ASC) AS hi,
ROW_NUMBER() OVER (ORDER BY value DESC) AS lo
WHERE hi IN (lo, lo+1, lo-1)
```
→ **両端から数えてぶつかる地点が中央**

**欠番の検出:**
```sql
LEAD(num) OVER (ORDER BY num) - num > 1
```
→ **次の値との差が1より大きければ欠番**

### メリット

✅ 自己結合を消去できる
✅ テーブルアクセス1回で済む
✅ 実行計画がシンプルで安定
✅ アプリケーション側のループ不要

**参照:**
- [knowledge/window-functions.md](../knowledge/window-functions.md#sqlと順序順序処理の応用パターン) - ウィンドウ関数の詳細解説
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#シーケンスidentity列の乱用) - シーケンス/IDENTITYの問題点
