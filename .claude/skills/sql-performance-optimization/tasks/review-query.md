# SQLクエリレビュー

## 目的
SQLクエリのパフォーマンス問題を発見し、改善案を提示する

---

## チェックリスト

### 1. 冗長性症候群（UNION vs CASE式）

#### チェックポイント
- [ ] **同じテーブルを複数回スキャンしていないか？**
  - UNIONで同じテーブルを複数回参照していないか
  - WHERE句で条件を変えて複数のSELECT文を実行していないか

- [ ] **CASE式で代替可能か？**
  - 条件分岐が必要な場合、SELECT句でCASE式を使えないか
  - 集計関数と組み合わせて1回のスキャンにできないか

#### 判断基準
```
同じテーブル？
  ├─ Yes → CASE式を使う（99%のケース）
  │
  └─ No（異なるテーブル）→ UNIONを使う

インデックスが効く？
  ├─ Yes + 選択率が低い → UNIONも検討
  └─ No → CASE式を使う
```

**参照:** [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#冗長性症候群unionによる条件分岐)

---

### 2. ぐるぐる系（N+1問題）

#### チェックポイント
- [ ] **アプリケーション側でループしていないか？**
  - 1行ずつSQLを発行していないか
  - 同じパターンのSQLが複数回実行されていないか

- [ ] **ウィンドウ関数で代替できないか？**
  - 前後の行を参照する処理 → LAG/LEAD
  - 累積計算 → SUM OVER
  - ランキング → RANK/ROW_NUMBER

- [ ] **一括処理できないか？**
  - IN句で複数IDを一度に取得
  - JOINで関連データを一括取得
  - 一括INSERT/UPDATEに変更

#### 判断基準
```
ループでSQL発行している？
  ├─ Yes → データ量は？
  │        ├─ 少ない（<100件） → 許容される場合も
  │        └─ 多い（>=100件） → ガツン系に書き換え
  │
  └─ No → OK
```

**参照:** [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#ぐるぐる系n1問題)

---

### 3. テーブルスキャン

#### チェックポイント
- [ ] **WHERE句に条件があるか？**
  - 全件取得していないか
  - 必要なデータだけに絞り込んでいるか

- [ ] **インデックスが使われているか？**
  - `EXPLAIN`で実行計画を確認
  - `Table scan` → インデックスが使われていない
  - `Index lookup` → インデックスが使われている

- [ ] **関数をWHERE句の列に適用していないか？**
  ```sql
  -- ❌ インデックスが使えない
  WHERE YEAR(created_at) = 2023

  -- ✅ インデックスが使える
  WHERE created_at >= '2023-01-01' AND created_at < '2024-01-01'
  ```

**参照:** [reference/execution-plan-keywords.md](../reference/execution-plan-keywords.md)

---

### 4. JOIN

#### チェックポイント

- [ ] **適切なJOIN条件があるか？**
  - ON句で適切に結合されているか
  - カーディナリティの低い列で結合していないか
  - **結合条件数 >= テーブル数 - 1** を満たすか？

- [ ] **駆動表は小さいか？**
  - FROM句の最初のテーブルが最小行数か
  - WHERE句で駆動表を絞り込んでいるか
  - `EXPLAIN` で駆動表の `rows` を確認

- [ ] **内部表の結合キーにインデックスあるか？**
  - 内部表の結合カラムにインデックスが存在するか
  - `EXPLAIN` で `Index lookup` が使われているか（`Table scan` でないか）
  - 複合キーの場合、結合カラムがインデックスの先頭にあるか

- [ ] **内部表のヒット件数が多すぎないか？**
  - 1行の駆動表に対して内部表が何行返るか
  - 内部表のWHERE句で絞り込めないか
  - 必要に応じてサブクエリで事前集約

- [ ] **意図せぬクロス結合が発生してないか？**
  - 全テーブルに結合条件があるか（孤立したテーブルがないか）
  - `EXPLAIN` で `rows` が異常に大きくないか
  - WHERE句結合（カンマ結合）を使っていないか → JOIN句に書き換え

- [ ] **不要なJOINがないか？**
  - 実際に使用していない列のためだけにJOINしていないか

#### 判断基準

```
結合が必要？
├─ NO  → ウィンドウ関数で代替できないか検討
└─ YES → 次へ

結合条件数 >= テーブル数 - 1？
├─ NO  → 三角結合のリスク → 結合条件を追加
└─ YES → 次へ

駆動表の行数 < 内部表の行数？
├─ NO  → FROM句の順序変更/WHERE句で絞り込み
└─ YES → 次へ

内部表の結合キーにインデックスあり？
├─ NO  → インデックス追加を検討
└─ YES → 次へ

内部表のヒット件数は適切？（駆動表1行あたり < 100行）
├─ NO  → WHERE句/サブクエリで絞り込み
└─ YES → OK
```

#### 悪い例と良い例

```sql
-- ❌ 悪い例1: 三角結合（結合条件不足）
SELECT *
FROM TableA A, TableB B, TableC C
WHERE A.id = B.id;
-- C が孤立 → 直積

-- ✅ 良い例1: 全テーブルに結合条件
SELECT *
FROM TableA A
JOIN TableB B ON A.id = B.id
JOIN TableC C ON B.id = C.id;

-- ❌ 悪い例2: 大きいテーブルが駆動表
SELECT *
FROM LargeTable L  -- 100万行
JOIN SmallTable S  -- 100行
  ON L.id = S.id;

-- ✅ 良い例2: 小さいテーブルが駆動表
SELECT *
FROM SmallTable S  -- 100行
JOIN LargeTable L  -- 100万行
  ON S.id = L.id;

-- ❌ 悪い例3: 内部表にインデックスなし
SELECT *
FROM SmallTable A
JOIN LargeTable B ON A.id = B.some_column;
-- B.some_column にインデックスなし → Table scan

-- ✅ 良い例3: インデックスあり
CREATE INDEX idx_some_column ON LargeTable(some_column);
SELECT *
FROM SmallTable A
JOIN LargeTable B ON A.id = B.some_column;
```

**参照:**
- [knowledge/join-algorithms.md](../knowledge/join-algorithms.md) - 結合アルゴリズムの詳細
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#意図せぬクロス結合三角結合) - 三角結合

---

### 5. サブクエリ

#### チェックポイント

- [ ] **同じテーブルに複数回アクセスしていないか？**
  - サブクエリ内のテーブルとFROM句のテーブルが同じではないか
  - `EXPLAIN` で同じテーブル名が2回以上出現していないか
  - テーブルアクセス回数が多い → **I/O増加**

- [ ] **サブクエリで結合が発生していないか？**
  - FROM句のサブクエリでJOINが発生していないか
  - 結合 → 実行計画変動リスク
  - ウィンドウ関数で置き換え可能か検討

- [ ] **ウィンドウ関数で置き換え可能か？**
  - MIN/MAX取得 → `ROW_NUMBER` で置き換え
  - 相関サブクエリ → `ROW_NUMBER` で置き換え
  - 集約結果の全行付与 → `MAX/MIN/AVG OVER` で置き換え
  - 前後の値参照 → `LAG/LEAD` で置き換え
  - 順位付け → `RANK/DENSE_RANK` で置き換え

- [ ] **相関サブクエリを使っていないか？**
  - WHERE句やSELECT句で外側の行を参照するサブクエリ
  - 外側の行ごとにループ実行される → 遅い
  - ウィンドウ関数またはJOINで代替

- [ ] **結合前に行数を絞れているか？**（サブクエリが有効なケース）
  - サブクエリで10倍以上削減できる場合は有効
  - 先に集約/絞り込み → 結合コスト削減

- [ ] **INサブクエリが大きすぎないか？**
  - IN句の中に大量のデータを含むサブクエリがないか
  - JOINやEXISTSで代替できないか

#### 判断基準

```
サブクエリを使っている？
├─ NO  → OK
└─ YES → 次へ

同じテーブルに複数回アクセス？
├─ NO  → 次へ
└─ YES → ウィンドウ関数で置き換え検討

サブクエリで結合が発生？
├─ NO  → 次へ
└─ YES → ウィンドウ関数で置き換え検討

結合前に行数を大幅に絞れる？（10倍以上）
├─ YES → サブクエリ有効（そのまま）
└─ NO  → ウィンドウ関数で置き換え
```

#### 悪い例と良い例

```sql
-- ❌ 悪い例1: サブクエリで集約 → 結合
SELECT R1.cust_id, R1.seq, R1.price
FROM Receipts R1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq
    FROM Receipts  -- ← Receiptsに2回アクセス
    GROUP BY cust_id
) R2
ON R1.cust_id = R2.cust_id
AND R1.seq = R2.min_seq;

-- ✅ 良い例1: ROW_NUMBERで置き換え
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

-- ❌ 悪い例2: 相関サブクエリ
SELECT cust_id, seq, price
FROM Receipts R1
WHERE seq = (
    SELECT MIN(seq)
    FROM Receipts R2
    WHERE R1.cust_id = R2.cust_id  -- 相関条件
);

-- ✅ 良い例2: ウィンドウ関数
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

-- ✅ 良い例3: サブクエリが有効なケース（結合前に絞り込み）
-- 500万行 → 1,000行に削減してから結合
SELECT C.co_cd, CSUM.total_emp
FROM Companies C
INNER JOIN (
    SELECT co_cd, SUM(emp_count) AS total_emp
    FROM Shops
    WHERE main_flg = 'Y'  -- 先に絞り込み
    GROUP BY co_cd
) CSUM
ON C.co_cd = CSUM.co_cd;
```

**参照:**
- [knowledge/subquery-problems.md](../knowledge/subquery-problems.md) - サブクエリの問題点
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md#サブクエリパラノイア) - サブクエリ・パラノイア
- [knowledge/window-functions.md](../knowledge/window-functions.md#サブクエリからウィンドウ関数への置き換え) - ウィンドウ関数への置き換えパターン

---

### 6. 集約関数

#### チェックポイント
- [ ] **CASE式 + 集約関数を使っているか？**
  - UNIONで複数回集計していないか
  - 1回のスキャンで複数の集計ができないか

- [ ] **ELSE句を適切に使っているか？**
  - `SUM + CASE`: ELSE 0 が必要
  - `COUNT + CASE`: ELSE句不要（NULLを除外）
  - `AVG/MAX/MIN + CASE`: ELSE句不要（NULLを除外）

**参照:** [examples/common-patterns.md](../examples/common-patterns.md#case式--集約関数のパターン)

---

### 7. GROUP BY / ORDER BY

#### チェックポイント
- [ ] **GROUP BY句に不要な列がないか？**
  - 必要最小限の列だけでグループ化しているか

- [ ] **ORDER BYが必要か？**
  - アプリケーション側でソートできないか
  - インデックスを利用できないか

- [ ] **HAVING句で条件分岐していないか？**
  ```sql
  -- ❌ HAVINGで条件分岐
  SELECT prefecture, SUM(pop) FROM Population WHERE sex = '1' GROUP BY prefecture
  UNION
  SELECT prefecture, SUM(pop) FROM Population WHERE sex = '2' GROUP BY prefecture;

  -- ✅ CASE式で条件分岐
  SELECT prefecture,
         SUM(CASE WHEN sex = '1' THEN pop ELSE 0 END) AS pop_men,
         SUM(CASE WHEN sex = '2' THEN pop ELSE 0 END) AS pop_wom
  FROM Population
  GROUP BY prefecture;
  ```

---

### 8. DISTINCT

#### チェックポイント
- [ ] **DISTINCTが本当に必要か？**
  - GROUP BYで代替できないか
  - JOINによる重複をより適切な方法で解決できないか

- [ ] **DISTINCTの範囲が適切か？**
  - 必要な列だけに適用されているか

---

### 9. LIMIT / OFFSET

#### チェックポイント
- [ ] **OFFSETが大きすぎないか？**
  ```sql
  -- ❌ OFFSETが大きい（遅い）
  SELECT * FROM users ORDER BY id LIMIT 10 OFFSET 100000;

  -- ✅ WHERE句で範囲指定（速い）
  SELECT * FROM users WHERE id > 100000 ORDER BY id LIMIT 10;
  ```

---

## レビュープロセス

### ステップ1: クエリを読む
1. クエリの目的を理解する
2. 複雑な部分を特定する
3. 明らかな問題を探す

### ステップ2: 実行計画を確認
```sql
EXPLAIN FORMAT=TREE
<対象クエリ>;
```

確認ポイント:
- Table scan の有無
- 使用されているインデックス
- 推定コスト（cost）
- 推定行数（rows）

### ステップ3: チェックリストで確認
上記のチェックリストを順番に確認

### ステップ4: 改善案を提示
1. 問題点を明確にする
2. 改善案を提示する
3. 期待される効果を説明する
4. Before/Afterで比較する

---

## レビュー報告テンプレート

```markdown
## レビュー結果

### 問題点
- [問題の説明]
- [該当するアンチパターン]

### 改善案
```sql
[改善後のクエリ]
```

### 期待される効果
- テーブルスキャン: X回 → Y回
- I/Oコスト: X → Y（Z%削減）
- 推定実行時間: X秒 → Y秒

### 実行計画の比較

#### Before
```
[改善前の実行計画]
```

#### After
```
[改善後の実行計画]
```

### 参考資料
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md)
- [examples/before-after.md](../examples/before-after.md)
```

---

## 参考リンク
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md) - アンチパターン集
- [examples/before-after.md](../examples/before-after.md) - 改善前後の例
- [examples/common-patterns.md](../examples/common-patterns.md) - よくあるパターン
- [reference/execution-plan-keywords.md](../reference/execution-plan-keywords.md) - 実行計画キーワード
