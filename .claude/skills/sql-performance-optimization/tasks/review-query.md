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

- [ ] **小さいテーブルから結合しているか？**
  - 結合順序が最適化されているか
  - 必要に応じてSTRAIGHT_JOINで順序を固定

- [ ] **不要なJOINがないか？**
  - 実際に使用していない列のためだけにJOINしていないか

**参照:** [knowledge/join-algorithms.md](../knowledge/join-algorithms.md)

---

### 5. サブクエリ

#### チェックポイント
- [ ] **相関サブクエリを使っていないか？**
  ```sql
  -- ❌ 相関サブクエリ（遅い）
  SELECT name
  FROM users u
  WHERE EXISTS (SELECT 1 FROM orders o WHERE o.user_id = u.id);

  -- ✅ JOIN（速い）
  SELECT DISTINCT u.name
  FROM users u
  INNER JOIN orders o ON o.user_id = u.id;
  ```

- [ ] **INサブクエリが大きすぎないか？**
  - IN句の中に大量のデータを含むサブクエリがないか
  - JOINやEXISTSで代替できないか

**参照:** [knowledge/subquery-problems.md](../knowledge/subquery-problems.md)

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
