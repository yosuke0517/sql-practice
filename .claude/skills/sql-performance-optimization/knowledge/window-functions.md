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
