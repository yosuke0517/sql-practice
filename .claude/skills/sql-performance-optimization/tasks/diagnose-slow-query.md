# 遅いクエリの診断

## 目的
遅いクエリの原因を特定し、具体的な改善策を提示する

---

## 診断フロー

### Step 1: 症状の確認

#### 収集すべき情報
- **実行時間**: 何秒かかっているか
- **発生頻度**: 常に遅いか、時々遅いか
- **データ量**: テーブルの行数、結合対象の行数
- **実行環境**: 本番環境か、開発環境か
- **リソース使用状況**: CPU、メモリ、ディスクI/O

#### 質問すべきこと
```
- このクエリは何をするためのものか？
- どのくらいのデータ量を扱っているか？
- 以前は速かったか？（データ量増加で遅くなった可能性）
- どれくらいの頻度で実行されるか？
```

---

### Step 2: 実行計画の取得

#### MySQL
```sql
EXPLAIN FORMAT=TREE
<対象クエリ>;
```

#### PostgreSQL
```sql
EXPLAIN (ANALYZE, BUFFERS)
<対象クエリ>;
```

#### 確認ポイント
| 項目 | チェック内容 |
|------|------------|
| **type** | ALL（全件スキャン）になっていないか |
| **rows** | 推定検査行数が多すぎないか |
| **cost** | 推定処理コストが高いか |
| **Extra** | Using filesort / Using temporary があるか（TEMP落ち） |
| **key** | インデックスが使われているか |

---

### Step 3: ボトルネックの特定

#### フルテーブルスキャン（Table scan）
```
-> Table scan on T  (cost=X rows=Y)
```

**症状:**
- `type = ALL` または `Table scan`
- インデックスが使われていない

**確認ポイント:**
- WHERE句に条件があるか
- インデックスが定義されているか
- インデックスが効かない条件になっていないか

#### 結合のコスト
```
-> Inner hash join  (cost=10000 rows=100000)
```

**症状:**
- `cost` が異常に高い
- `rows` が異常に多い（駆動表 × 内部表の直積になっている可能性）

**確認ポイント:**
- 駆動表は小さいか
- 内部表の結合キーにインデックスがあるか
- 意図せぬクロス結合が発生していないか

#### TEMP落ち
```
-- MySQL
Extra: Using filesort; Using temporary

-- PostgreSQL
Sort Method: external merge  Disk: 102400kB
```

**症状:**
- ディスクへの書き出しが発生
- パフォーマンスが劇的に悪化

**確認ポイント:**
- GROUP BY、ORDER BY、ウィンドウ関数の使用
- データ量が多い
- ワーキングメモリが不足

---

### Step 4: 原因の分類

#### 1. インデックス問題

**チェック項目:**
- [ ] インデックスが定義されているか
- [ ] インデックスが使われているか（EXPLAIN で確認）
- [ ] インデックスが効かない5パターンに該当しないか
  1. LIKE中間・後方一致
  2. 列を加工（計算・関数）
  3. 否定形（`<>`, `NOT IN`）
  4. IS NULL
  5. 選択率が高い（90%ヒット等）
- [ ] 複合インデックスの順序は適切か

**参照:** [knowledge/index-strategies.md](../knowledge/index-strategies.md)

---

#### 2. 結合問題

**チェック項目:**
- [ ] 駆動表は小さいか（FROM句の順序）
- [ ] 内部表の結合キーにインデックスがあるか
- [ ] 内部表のヒット件数が多すぎないか
- [ ] 意図せぬクロス結合が発生していないか
  - 結合条件数 >= テーブル数 - 1 を満たすか
- [ ] 不要な結合がないか

**参照:** [knowledge/join-algorithms.md](../knowledge/join-algorithms.md)

---

#### 3. サブクエリ問題

**チェック項目:**
- [ ] 同じテーブルに複数回アクセスしていないか
- [ ] サブクエリで結合が発生していないか
- [ ] 相関サブクエリを使っていないか
- [ ] ウィンドウ関数で置き換え可能か
  - MIN/MAX取得 → `ROW_NUMBER`
  - 集約結果の全行付与 → `MAX/MIN/AVG OVER`
  - 前後の値参照 → `LAG/LEAD`
  - 順位付け → `RANK/DENSE_RANK`

**参照:** [knowledge/subquery-problems.md](../knowledge/subquery-problems.md)

---

#### 4. アンチパターン

**チェック項目:**
- [ ] **冗長性症候群**: 同じテーブルをUNIONで複数回スキャン → CASE式で1回に
- [ ] **N+1問題**: ループでSQL発行 → ガツン系で一括処理
- [ ] **三角結合**: 結合条件不足で直積 → 結合条件を追加
- [ ] **サブクエリ・パラノイア**: テーブル複数回アクセス → ウィンドウ関数
- [ ] **スーパーソルジャー病**: SQLで無理やり解決 → データモデルを見直す

**参照:** [knowledge/anti-patterns.md](../knowledge/anti-patterns.md)

---

### Step 5: 改善策の提示

#### 改善策の優先順位

```
1位: データモデルの見直し（根本的解決）
  → 毎回結合+集約が必要なら、集計列を追加

2位: インデックスの追加・修正
  → 最も即効性がある

3位: クエリの書き換え
  → サブクエリ → ウィンドウ関数
  → UNION → CASE式
  → ループ → ガツン系

4位: ワーキングメモリの増加
  → TEMP落ち対策
```

---

## よくある原因と対処法

| 原因 | 症状（EXPLAIN） | 対処法 | 参照 |
|------|----------------|--------|------|
| **インデックス未使用** | `Table scan`, `type=ALL` | インデックス追加 or WHERE句修正 | [index-strategies.md](../knowledge/index-strategies.md) |
| **列を加工** | `Table scan` | 右辺で計算（`WHERE col > 100/1.1`） | [index-strategies.md](../knowledge/index-strategies.md#❌-2-列を加工計算関数) |
| **LIKE中間一致** | `Table scan` | 前方一致に変更 or 全文検索インデックス | [index-strategies.md](../knowledge/index-strategies.md#❌-1-like中間後方一致) |
| **大きい駆動表** | `rows` が大きい | FROM句の順序変更 or WHERE句で絞り込み | [join-algorithms.md](../knowledge/join-algorithms.md#駆動表は小さいか) |
| **内部表インデックスなし** | `Table scan on 内部表` | 内部表の結合キーにインデックス追加 | [join-algorithms.md](../knowledge/join-algorithms.md#内部表の結合キーにインデックスあるか) |
| **三角結合** | `rows` が異常に大きい（直積） | 結合条件を追加（結合条件数 = テーブル数 - 1） | [anti-patterns.md](../knowledge/anti-patterns.md#意図せぬクロス結合三角結合) |
| **サブクエリ結合** | 同じテーブルが2回出現 | ウィンドウ関数で置き換え | [subquery-problems.md](../knowledge/subquery-problems.md) |
| **N+1問題** | 同じSQLが大量発行 | ガツン系に書き換え（JOIN, IN句, ウィンドウ関数） | [anti-patterns.md](../knowledge/anti-patterns.md#ぐるぐる系n1問題) |
| **TEMP落ち** | `Using filesort/temporary` | ワーキングメモリ増 or WHERE句で絞り込み or インデックス活用 | [temp-fall.md](../knowledge/temp-fall.md) |
| **冗長性症候群** | 同じテーブルが複数回 | UNION → CASE式に書き換え | [anti-patterns.md](../knowledge/anti-patterns.md#冗長性症候群unionによる条件分岐) |

---

## 診断チェックリスト

### 基本チェック
- [ ] **WHERE句に条件があるか？**
  - 全件取得していないか
  - 必要なデータだけに絞り込んでいるか

- [ ] **フルテーブルスキャンになっていないか？**
  - `Table scan` が出ていないか
  - `type = ALL` になっていないか

- [ ] **インデックスが効いているか？**
  - `Index lookup` が使われているか
  - `key` にインデックス名が表示されているか

### インデックスチェック
- [ ] **インデックスが効かない5パターンに該当しないか？**
  1. `LIKE '%keyword%'` （中間・後方一致）
  2. `WHERE YEAR(date) = 2024` （列を加工）
  3. `WHERE status <> 'deleted'` （否定形）
  4. `WHERE col IS NULL`
  5. 選択率が高い（90%がヒット等）

- [ ] **複合インデックスの順序は適切か？**
  - WHERE句の条件がインデックスの先頭列から順に使われているか

### 結合チェック
- [ ] **駆動表は適切か？**
  - 小さいテーブルが駆動表になっているか
  - `rows` の値が小さいか

- [ ] **内部表の結合キーにインデックスがあるか？**
  - 内部表で `Index lookup` が使われているか

- [ ] **意図せぬクロス結合が発生していないか？**
  - `結合条件数 = テーブル数 - 1` を満たすか
  - `rows` が異常に大きくないか

### サブクエリチェック
- [ ] **同じテーブルに複数回アクセスしていないか？**
  - EXPLAIN で同じテーブル名が2回以上出現していないか

- [ ] **ウィンドウ関数で置き換え可能か？**
  - MIN/MAX取得、集約結果付与、前後参照、順位付け

### その他
- [ ] **TEMP落ちが発生していないか？**
  - `Using filesort` / `Using temporary` が出ていないか

- [ ] **N+1問題が発生していないか？**
  - アプリケーションログで同じSQLが大量発行されていないか

---

## 診断結果レポートテンプレート

```markdown
## 診断結果

### 1. 問題の概要
- **実行時間**: X秒
- **発生頻度**: [常に遅い / 時々遅い / データ量増加で悪化]
- **データ量**: [テーブル行数]

### 2. EXPLAIN分析結果

#### 実行計画
\```
[EXPLAIN結果を貼り付け]
\```

#### ボトルネック箇所
- **Table scan**: [テーブル名] (cost=X rows=Y)
- **高コスト結合**: [詳細]
- **TEMP落ち**: [あり/なし]

### 3. 原因

#### 主要な問題点
1. [問題1]
   - 該当箇所: [コード行数 or テーブル名]
   - アンチパターン: [冗長性症候群 / N+1問題 / 三角結合 / サブクエリ・パラノイア / etc.]

2. [問題2]
   ...

### 4. 改善策

#### 推奨する改善策（優先順位順）

**1. [改善策1]**
\```sql
[改善後のクエリ]
\```

**期待される効果:**
- テーブルアクセス: X回 → Y回
- インデックス使用: なし → あり
- 推定コスト: X → Y（Z%削減）

**2. [改善策2]**
...

### 5. 改善後のEXPLAIN（期待値）

\```
[改善後の実行計画（想定）]
\```

### 6. 参考資料
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md)
- [knowledge/index-strategies.md](../knowledge/index-strategies.md)
- [examples/before-after.md](../examples/before-after.md)
```

---

## 参考リンク

- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md) - アンチパターン集
- [knowledge/index-strategies.md](../knowledge/index-strategies.md) - インデックス戦略
- [knowledge/join-algorithms.md](../knowledge/join-algorithms.md) - 結合アルゴリズム
- [knowledge/subquery-problems.md](../knowledge/subquery-problems.md) - サブクエリの問題
- [knowledge/temp-fall.md](../knowledge/temp-fall.md) - TEMP落ち対策
- [tasks/review-query.md](./review-query.md) - SQLクエリレビュー
- [examples/before-after.md](../examples/before-after.md) - 改善前後の例
