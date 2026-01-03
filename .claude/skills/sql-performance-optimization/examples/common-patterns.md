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

---

## 更新系パターン（UPDATE文でのウィンドウ関数活用）

> 「更新処理でもウィンドウ関数で一括処理。テーブルアクセスを1回に減らせ」

---

### パターン13: NULLの埋め立て（前の値で補完）

#### 用途
NULL値を前の非NULL値で埋める（センサーデータの欠損補完など）

#### Before
| keycol | seq | val |
|--------|-----|-----|
| A | 1 | 50 |
| A | 2 | NULL |
| A | 3 | NULL |
| A | 4 | 70 |

#### After（期待する結果）
| keycol | seq | val |
|--------|-----|-----|
| A | 1 | 50 |
| A | 2 | 50 | ← 前の値で埋める
| A | 3 | 50 | ← 前の値で埋める
| A | 4 | 70 |

---

#### ❌ 相関サブクエリ版（遅い）

```sql
-- テーブルに3回アクセス
UPDATE OmitTbl
SET val = (SELECT val
           FROM OmitTbl O1
           WHERE O1.keycol = OmitTbl.keycol
             AND O1.seq = (SELECT MAX(seq)
                           FROM OmitTbl O2
                           WHERE O2.keycol = OmitTbl.keycol
                             AND O2.seq < OmitTbl.seq
                             AND O2.val IS NOT NULL))
WHERE val IS NULL;
```

**問題点:**
- テーブルに3回アクセス
- 相関サブクエリでループ
- ネストしたサブクエリで複雑

---

#### ✅ ウィンドウ関数版（Oracle/SQL Server）

```sql
-- LAST_VALUE IGNORE NULLS を使用
UPDATE OmitTbl
SET val = (SELECT val
           FROM (SELECT keycol, seq,
                        LAST_VALUE(val IGNORE NULLS) OVER (
                            PARTITION BY keycol
                            ORDER BY seq
                            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
                        ) AS filled_val
                 FROM OmitTbl) tmp
           WHERE tmp.keycol = OmitTbl.keycol
             AND tmp.seq = OmitTbl.seq)
WHERE val IS NULL;
```

**改善点:**
- ✅ テーブルアクセス2回（元々3回から削減）
- ✅ ループなし
- ✅ 可読性が向上

---

#### MySQL での代替案（再帰CTE）

```sql
-- 再帰CTEで前の値を伝播
WITH RECURSIVE filled AS (
    -- ベースケース: seq=1の行
    SELECT keycol, seq, val, val AS filled_val
    FROM OmitTbl
    WHERE seq = 1

    UNION ALL

    -- 再帰ケース: seq=2以降
    SELECT o.keycol, o.seq, o.val,
           COALESCE(o.val, f.filled_val) AS filled_val
    FROM OmitTbl o
    INNER JOIN filled f
      ON o.keycol = f.keycol
     AND o.seq = f.seq + 1
)
UPDATE OmitTbl o
INNER JOIN filled f
  ON o.keycol = f.keycol
 AND o.seq = f.seq
SET o.val = f.filled_val
WHERE o.val IS NULL;
```

**メリット:**
- MySQL 8.0+ で動作
- 再帰的に前の値を伝播

**デメリット:**
- 再帰CTEの記述が複雑
- seqが連番でないと動作しない

---

### パターン14: 行から列への更新（行持ち→列持ち UPDATE）

#### 用途
複数行に分散したデータを1行にまとめて更新する

#### Before（ScoreRows）
| student_id | subject | score |
|------------|---------|-------|
| A001 | 英語 | 100 |
| A001 | 国語 | 58 |
| A001 | 数学 | 90 |
| B002 | 英語 | 77 |
| B002 | 国語 | 60 |

#### After（ScoreCols）
| student_id | score_en | score_nl | score_mt |
|------------|----------|----------|----------|
| A001 | 100 | 58 | 90 |
| B002 | 77 | 60 | NULL |

---

#### ✅ CASE式 + 集約での一括UPDATE

```sql
-- ScoreColsテーブルが既に存在する場合
UPDATE ScoreCols
SET score_en = (SELECT MAX(CASE WHEN subject = '英語' THEN score END)
                FROM ScoreRows SR
                WHERE SR.student_id = ScoreCols.student_id),
    score_nl = (SELECT MAX(CASE WHEN subject = '国語' THEN score END)
                FROM ScoreRows SR
                WHERE SR.student_id = ScoreCols.student_id),
    score_mt = (SELECT MAX(CASE WHEN subject = '数学' THEN score END)
                FROM ScoreRows SR
                WHERE SR.student_id = ScoreCols.student_id);
```

**改善版（サブクエリを1回に）:**

```sql
-- サブクエリを1回にまとめる
UPDATE ScoreCols C
INNER JOIN (
    SELECT student_id,
           MAX(CASE WHEN subject = '英語' THEN score END) AS en,
           MAX(CASE WHEN subject = '国語' THEN score END) AS nl,
           MAX(CASE WHEN subject = '数学' THEN score END) AS mt
    FROM ScoreRows
    GROUP BY student_id
) SR
  ON C.student_id = SR.student_id
SET C.score_en = SR.en,
    C.score_nl = SR.nl,
    C.score_mt = SR.mt;
```

**メリット:**
- 一括更新
- CASE式でシンプル
- テーブルアクセスを最小化

---

#### 新しいテーブルを作る場合（推奨）

```sql
-- INSERT SELECTが推奨
CREATE TABLE ScoreCols AS
SELECT student_id,
       MAX(CASE WHEN subject = '英語' THEN score END) AS score_en,
       MAX(CASE WHEN subject = '国語' THEN score END) AS score_nl,
       MAX(CASE WHEN subject = '数学' THEN score END) AS score_mt
FROM ScoreRows
GROUP BY student_id;
```

---

### パターン15: 前日比計算（同じテーブルの異なる行からの更新）

#### 用途
前日の価格と比較して増減を記録する

#### Before
| brand | date | price | trend |
|-------|------|-------|-------|
| A | 01/01 | 1000 | NULL |
| A | 01/02 | 1050 | NULL |
| A | 01/03 | 1050 | NULL |
| A | 01/04 | 900 | NULL |

#### After（期待する結果）
| brand | date | price | trend |
|-------|------|-------|-------|
| A | 01/01 | 1000 | NULL |
| A | 01/02 | 1050 | ↑ |
| A | 01/03 | 1050 | → |
| A | 01/04 | 900 | ↓ |

---

#### ❌ 相関サブクエリ版（遅い）

```sql
-- 複雑で読みにくい、テーブル複数回アクセス
UPDATE Stocks
SET trend = (SELECT CASE SIGN(Stocks.price -
                              (SELECT price
                               FROM Stocks S2
                               WHERE S2.brand = Stocks.brand
                                 AND S2.sale_date = (SELECT MAX(sale_date)
                                                     FROM Stocks S3
                                                     WHERE S3.brand = Stocks.brand
                                                       AND S3.sale_date < Stocks.sale_date)))
                  WHEN 1 THEN '↑'
                  WHEN 0 THEN '→'
                  WHEN -1 THEN '↓'
             END);
```

**問題点:**
- テーブルに3回アクセス
- ネストしたサブクエリで複雑
- 可読性が低い

---

#### ✅ ウィンドウ関数版（INSERT版 - 推奨）

```sql
-- 新しいテーブルに挿入（テーブルアクセス1回）
INSERT INTO Stocks2
SELECT brand, sale_date, price,
       CASE SIGN(price - LAG(price) OVER (
                PARTITION BY brand
                ORDER BY sale_date
            ))
            WHEN 1 THEN '↑'
            WHEN 0 THEN '→'
            WHEN -1 THEN '↓'
            ELSE NULL
       END AS trend
FROM Stocks;
```

**メリット:**
- ✅ テーブルアクセス1回のみ
- ✅ 結合なし
- ✅ 可読性が高い
- ✅ LAG関数で前の行を直接参照

---

#### ✅ ウィンドウ関数版（UPDATE版）

```sql
-- 既存テーブルを更新（テーブルアクセス2回）
UPDATE Stocks S
INNER JOIN (
    SELECT brand, sale_date,
           CASE SIGN(price - LAG(price) OVER (
                    PARTITION BY brand
                    ORDER BY sale_date
                ))
                WHEN 1 THEN '↑'
                WHEN 0 THEN '→'
                WHEN -1 THEN '↓'
                ELSE NULL
           END AS trend_value
    FROM Stocks
) AS tmp
  ON S.brand = tmp.brand
 AND S.sale_date = tmp.sale_date
SET S.trend = tmp.trend_value;
```

**改善点:**
- ✅ テーブルアクセス2回（元々3回から削減）
- ✅ 可読性が高い

---

### パターン16: 累積値の更新

#### 用途
累積売上を計算してテーブルに保存する

#### Before
| date | sales | cumulative_sales |
|------|-------|------------------|
| 01/01 | 100 | NULL |
| 01/02 | 200 | NULL |
| 01/03 | 150 | NULL |

#### After
| date | sales | cumulative_sales |
|------|-------|------------------|
| 01/01 | 100 | 100 |
| 01/02 | 200 | 300 |
| 01/03 | 150 | 450 |

---

#### ❌ ループ版（遅い）

```java
// アプリケーション側でループ
cumulative = 0;
for (row : sales) {
    cumulative += row.sales;
    UPDATE Sales SET cumulative_sales = ? WHERE date = ?;
}
```

**問題点:**
- N回の更新SQL発行
- ネットワークラウンドトリップ × N
- トランザクションログ肥大化

---

#### ✅ ウィンドウ関数版（速い）

```sql
-- サブクエリでSUM OVERを使い、結果で更新
UPDATE Sales S
INNER JOIN (
    SELECT date,
           SUM(sales) OVER (ORDER BY date) AS cumulative
    FROM Sales
) AS tmp
  ON S.date = tmp.date
SET S.cumulative_sales = tmp.cumulative;
```

**改善点:**
- ✅ テーブルアクセス2回（一括処理）
- ✅ 1回のUPDATE文で完了
- ✅ パフォーマンス向上

---

## 更新系パターン まとめ

### 主要パターン比較

| パターン | 処理内容 | 従来の方法 | ウィンドウ関数 | アクセス削減 |
|---------|---------|-----------|--------------|------------|
| **13** | NULL埋め立て | 相関サブクエリ | LAST_VALUE IGNORE NULLS | 3回 → 2回 |
| **14** | 行列変換UPDATE | 複数サブクエリ | CASE + 集約 + 結合 | N回 → 2回 |
| **15** | 前日比計算 | 相関サブクエリ | LAG + SIGN + CASE | 3回 → 2回（INSERT版は1回） |
| **16** | 累積値更新 | ループ | SUM OVER | N回 → 2回 |

### 推奨アプローチ

**新しいテーブルを作る場合:**
```sql
-- INSERT SELECT が推奨（テーブルアクセス1回）
INSERT INTO NewTable
SELECT ..., ウィンドウ関数 OVER (...) AS new_col
FROM OldTable;
```

**既存テーブルを更新する場合:**
```sql
-- サブクエリ + 結合でUPDATE（テーブルアクセス2回）
UPDATE OldTable O
INNER JOIN (
    SELECT key, ウィンドウ関数 OVER (...) AS new_val
    FROM OldTable
) AS tmp
  ON O.key = tmp.key
SET O.col = tmp.new_val;
```

### メリット

✅ テーブルアクセス回数の削減
✅ 一括処理で高速化
✅ 可読性の向上
✅ 実行計画がシンプル

### 注意点

⚠️ **DBMS依存性**
- `IGNORE NULLS`: Oracle、SQL Server（PostgreSQL 11+も対応）
- MySQL: 再帰CTEで代替

⚠️ **大量データの更新**
- 一時テーブルのメモリ使用に注意
- TEMP落ちリスク

**参照:**
- [knowledge/window-functions.md](../knowledge/window-functions.md#update文でのウィンドウ関数活用) - UPDATE文でのウィンドウ関数の詳細
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#ぐるぐる系n1問題) - ループ更新の問題点
