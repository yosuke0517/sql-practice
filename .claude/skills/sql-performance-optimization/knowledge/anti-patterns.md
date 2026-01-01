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
