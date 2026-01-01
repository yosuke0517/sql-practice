# サブクエリの問題点

> 「SQLパフォーマンスの要諦: 1にI/O、2にI/O、3、4がなくて5にI/O」

---

## 概要

サブクエリは**コードの可読性を高める**便利な機能だが、パフォーマンスの観点では深刻な問題を引き起こす。

**サブクエリ・パラノイア（Subquery Paranoia）** とは、サブクエリを使うことで発生する性能劣化の総称。

---

## サブクエリの4つの問題点

### 1. 一時領域にデータを確保 → オーバーヘッド

サブクエリの結果は一時的な作業領域（TEMP領域）に保存される。

```sql
SELECT *
FROM Orders O
INNER JOIN (
    SELECT customer_id, SUM(amount) AS total
    FROM Payments
    GROUP BY customer_id
) P ON O.customer_id = P.customer_id;
```

**問題:**
- サブクエリの結果を一時テーブルに保存
- メモリ不足なら**TEMP落ち**（ディスクI/O発生）
- オーバーヘッドが大きい

### 2. インデックスや制約が使えない → 最適化されない

一時テーブルには元のテーブルのインデックスや制約が引き継がれない。

```sql
-- 元テーブル: customer_id にインデックスあり
-- サブクエリ結果: customer_id にインデックスなし
```

**問題:**
- オプティマイザが最適化できない
- 結合時にTable scanになる可能性

### 3. 結合が発生 → コスト高 & 実行計画変動リスク

サブクエリを使うと、必然的に結合が発生する。

**問題:**
- 結合アルゴリズムの選択が発生（Nested Loops / Hash / Sort Merge）
- データ量が増えると実行計画が変動
- 性能が不安定になる

### 4. テーブルへのスキャンが増える → I/O増加

サブクエリを使うと、同じテーブルに複数回アクセスすることになる。

```sql
-- ❌ 悪い例: Receiptsテーブルに2回アクセス
SELECT R1.cust_id, R1.seq, R1.price
FROM Receipts R1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq
    FROM Receipts  -- ← 1回目
    GROUP BY cust_id
) R2
ON R1.cust_id = R2.cust_id  -- ← 2回目（R1として）
AND R1.seq = R2.min_seq;
```

**問題:**
- テーブルスキャン回数が増える
- **I/Oが最大のボトルネック**
- 性能が劣化する

---

## 典型的なダメパターン

### パターン1: サブクエリで集約 → 結合

```sql
-- ❌ 悪い例: 最小値をサブクエリで取得して結合
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

**問題:**
- Receiptsテーブルに2回アクセス（R1とR2）
- 結合が発生（コスト高）
- 実行計画変動リスク

**実行計画例:**
```
-> Inner hash join  (cost=500 rows=100)
    -> Table scan on R1  (cost=200 rows=10000)  ← 1回目
    -> Hash
        -> Table scan on Receipts  (cost=200 rows=10000)  ← 2回目
            -> Aggregate using temp table
```

### パターン2: 相関サブクエリ

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

**問題:**
- やっぱりテーブルに2回アクセス
- 外側の行ごとに内側のSQLを実行（ループ）
- 実行計画は結合とほぼ同じ

**実行計画例:**
```
-> Filter: (R1.seq = (select #2))
    -> Table scan on R1  (cost=200 rows=10000)  ← 1回目
    -> Select #2
        -> Aggregate
            -> Filter: (R1.cust_id = R2.cust_id)
                -> Table scan on R2  (cost=200 rows=10000)  ← 2回目
```

---

## 解決策：ウィンドウ関数で結合をなくす

```sql
-- ✅ 良い例: ウィンドウ関数
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
- ✅ I/Oが最小化

**実行計画例:**
```
-> Filter: (WORK.row_seq = 1)
    -> Window aggregate
        -> Table scan on Receipts  (cost=200 rows=10000)  ← 1回のみ
```

---

## サブクエリが有効なケース（例外）

### 結合前に行数を絞れる場合

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

---

## I/Oの重要性

```
SQLパフォーマンスのボトルネック:
  1位: ディスクI/O（圧倒的）
  2位: メモリアクセス
  3位: CPU処理

テーブルアクセス回数の影響:
  1回 → 2回: 約2倍遅くなる
  1回 → 3回: 約3倍遅くなる
```

**パフォーマンス改善の鉄則:**
- テーブルアクセス回数を最小化
- 結合を減らす
- サブクエリをウィンドウ関数で置き換える

---

## 判断フロー

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

---

## まとめ

### サブクエリの問題点

❌ 一時領域にデータ確保 → オーバーヘッド
❌ インデックスや制約が使えない
❌ 結合が発生 → 実行計画変動リスク
❌ テーブルスキャンが増える → **I/O増加**

### 解決策

✅ ウィンドウ関数で結合を消去
✅ テーブルアクセスを1回に
✅ I/Oを最小化

### 例外（サブクエリが有効）

✅ 結合前に行数を大幅に絞れる場合（10倍以上）

### 心構え

- **思考の補助**としてサブクエリを使うのはOK
- **最終的には統合**してシンプルにする
- 「困難は分割するな」

---

## 参照

- [アンチパターン](./anti-patterns.md#サブクエリパラノイア) - サブクエリ・パラノイア
- [ウィンドウ関数](./window-functions.md#サブクエリからウィンドウ関数への置き換え) - サブクエリ置き換えパターン
- [結合アルゴリズム](./join-algorithms.md) - 結合のコストと実行計画変動
- [クエリレビュータスク](../tasks/review-query.md#5-サブクエリ) - サブクエリチェックリスト
