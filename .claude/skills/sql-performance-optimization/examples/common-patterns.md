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
