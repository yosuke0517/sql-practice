# 改善前後の例

## 条件分岐：UNION → CASE式

### 例1: 年度による価格列の切り替え

#### 要件
2001年以前は税抜き価格、2002年以降は税込み価格を表示したい

#### Before（❌ 悪い例）
```sql
SELECT item_name, year, price_tax_ex AS price
FROM Items
WHERE year <= 2001
UNION ALL
SELECT item_name, year, price_tax_in AS price
FROM Items
WHERE year >= 2002;
```

**実行計画:**
```
-> Append
   -> Table scan on Items (cost=0.55 rows=5)   ← 1回目
   -> Table scan on Items (cost=0.55 rows=5)   ← 2回目
```

**問題点:**
- Itemsテーブルを2回スキャン
- I/Oコスト: 0.55 × 2 = 1.1
- スキャン行数: 5 × 2 = 10行

#### After（✅ 良い例）
```sql
SELECT item_name, year,
       CASE WHEN year <= 2001 THEN price_tax_ex
            WHEN year >= 2002 THEN price_tax_in
       END AS price
FROM Items;
```

**実行計画:**
```
-> Table scan on Items (cost=0.55 rows=5)   ← 1回だけ！
```

**改善点:**
- Itemsテーブルを1回スキャン
- I/Oコスト: 0.55（半減）
- スキャン行数: 5行（半減）

**パフォーマンス向上:**
- I/Oコスト: 50%削減
- スキャン行数: 50%削減

---

## 集計における条件分岐：UNION → CASE式

### 例2: 都道府県別の男女別人口集計

#### 要件
都道府県別に男女の人口を列で分けて表示したい

| prefecture | pop_men | pop_wom |
|-----------|---------|---------|
| 東京 | 90 | 100 |
| 大阪 | 60 | 40 |

#### Before（❌ 悪い例）
```sql
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

**実行計画:**
```
-> Group aggregate
   -> Sort
      -> Unique
         -> Append
            -> Filter: (sex = '1')
               -> Table scan on Population  ← 1回目
            -> Filter: (sex = '2')
               -> Table scan on Population  ← 2回目
```

**問題点:**
- Populationテーブルを2回スキャン
- UNION によるソート処理（重複除去）
- サブクエリによる複雑性

#### After（✅ 良い例）
```sql
SELECT prefecture,
       SUM(CASE WHEN sex = '1' THEN pop ELSE 0 END) AS pop_men,
       SUM(CASE WHEN sex = '2' THEN pop ELSE 0 END) AS pop_wom
FROM Population
GROUP BY prefecture;
```

**実行計画:**
```
-> Group aggregate
   -> Sort
      -> Table scan on Population  ← 1回だけ！
```

**改善点:**
- Populationテーブルを1回スキャン
- ソート処理が1回で済む
- シンプルで読みやすい

**パフォーマンス向上:**
- テーブルスキャン: 50%削減
- ソート対象行数: 50%削減
- 実行計画の複雑性: 大幅削減

---

## 複数条件の集約：UNION → CASE式

### 例3: ステータス別の売上集計

#### 要件
商品の販売状態（在庫あり、予約受付中、販売終了）ごとに売上を集計

#### Before（❌ 悪い例）
```sql
SELECT 'in_stock' AS status, SUM(price) AS total
FROM Products
WHERE stock > 0
UNION ALL
SELECT 'pre_order' AS status, SUM(price) AS total
FROM Products
WHERE stock = 0 AND available_date > CURDATE()
UNION ALL
SELECT 'sold_out' AS status, SUM(price) AS total
FROM Products
WHERE stock = 0 AND available_date <= CURDATE();
```

**問題点:**
- Productsテーブルを3回スキャン
- 各条件で別々に集計
- I/Oコスト3倍

#### After（✅ 良い例）
```sql
SELECT
    SUM(CASE WHEN stock > 0 THEN price ELSE 0 END) AS in_stock,
    SUM(CASE WHEN stock = 0 AND available_date > CURDATE() THEN price ELSE 0 END) AS pre_order,
    SUM(CASE WHEN stock = 0 AND available_date <= CURDATE() THEN price ELSE 0 END) AS sold_out
FROM Products;
```

**改善点:**
- Productsテーブルを1回スキャン
- 1つのクエリで全ての集計が完了
- I/Oコスト: 66%削減

---

## まとめ

| パターン | Before | After | 削減率 |
|---------|--------|-------|--------|
| 条件分岐（列切替） | テーブル2回スキャン | 1回スキャン | 50% |
| 集計（男女別） | テーブル2回スキャン + UNION | 1回スキャン | 50% |
| 複数条件集約 | テーブル3回スキャン | 1回スキャン | 66% |

**共通の改善ポイント:**
1. テーブルスキャン回数の削減
2. I/Oコストの削減
3. 実行計画のシンプル化
4. 可読性の向上
