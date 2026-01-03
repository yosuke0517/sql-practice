# インデックス設計

## 目的
クエリのパフォーマンスを最大化するために、適切なインデックスを設計・提案する

---

## インデックス設計の手順

### Step 1: クエリパターンの洗い出し

#### 収集すべき情報
- [ ] **頻繁に実行されるクエリ** - スロークエリログ、APMツールから特定
- [ ] **重要なクエリ** - ユーザー体験に直結するクエリ（検索、一覧表示等）
- [ ] **遅いクエリ** - EXPLAIN で `type = ALL` になっているクエリ

#### 質問すべきこと
```
- どのクエリを最適化したいか？
- どのくらいの頻度で実行されるか？
- データ量はどのくらいか？
- 今後どのくらい増えるか？
```

#### 実践例
```sql
-- スロークエリログから抽出
-- 1. ユーザー検索（頻度: 高）
SELECT * FROM users WHERE email = 'user@example.com';

-- 2. 注文一覧（頻度: 高）
SELECT * FROM orders WHERE user_id = 123 ORDER BY created_at DESC;

-- 3. 売上集計（頻度: 中）
SELECT shop_id, SUM(amount) FROM orders
WHERE created_at >= '2024-01-01'
GROUP BY shop_id;
```

---

### Step 2: WHERE/JOIN/ORDER BYで使われるカラムの特定

#### チェック項目

| 句 | 確認すべき内容 | インデックス候補 |
|----|--------------|----------------|
| **WHERE** | 絞り込み条件に使われるカラム | ✅ 最優先 |
| **JOIN** | 結合条件に使われるカラム | ✅ 最優先 |
| **ORDER BY** | ソートに使われるカラム | ○ 重要 |
| **GROUP BY** | 集約に使われるカラム | △ 場合による |

#### 実践例

**クエリ1: ユーザー検索**
```sql
SELECT * FROM users WHERE email = 'user@example.com';
```
→ **インデックス候補:** `email`

---

**クエリ2: 注文一覧**
```sql
SELECT * FROM orders WHERE user_id = 123 ORDER BY created_at DESC;
```
→ **インデックス候補:** `user_id`, `created_at`

---

**クエリ3: 売上集計**
```sql
SELECT shop_id, SUM(amount) FROM orders
WHERE created_at >= '2024-01-01'
GROUP BY shop_id;
```
→ **インデックス候補:** `created_at`, `shop_id`

---

**クエリ4: 結合**
```sql
SELECT O.*, U.name
FROM orders O
JOIN users U ON O.user_id = U.id
WHERE O.status = 'completed';
```
→ **インデックス候補:**
- `orders.status`（WHERE句）
- `orders.user_id`（JOIN）
- `users.id`（JOIN、通常はPRIMARY KEYなので不要）

---

### Step 3: カーディナリティの確認

#### カーディナリティとは
値のばらつき度合い。インデックスの効果を左右する重要な指標。

| カーディナリティ | 例 | インデックス効果 |
|---------------|---|----------------|
| **高い** | ユーザーID、メールアドレス、注文番号 | ✅ 効果大 |
| **中程度** | 都道府県（47種類）、カテゴリ（数十種類） | △ 場合による |
| **低い** | 性別（M/F）、フラグ（0/1）、ステータス（数種類） | ❌ 効果小 |

#### 確認方法

```sql
-- カーディナリティ確認
SELECT COUNT(DISTINCT column_name) AS cardinality,
       COUNT(*) AS total_rows,
       ROUND(COUNT(DISTINCT column_name) * 100.0 / COUNT(*), 2) AS selectivity_pct
FROM table_name;
```

**判断基準:**
- **選択率 5〜10% 以下** → インデックス効果あり
- **選択率 50% 以上** → フルスキャンの方が速い

#### 実践例

```sql
-- 例: orders テーブル（100万行）

-- status カラム
SELECT COUNT(DISTINCT status) AS cardinality FROM orders;
-- 結果: 3種類（pending, completed, cancelled）
-- → カーディナリティ低い、インデックス効果薄い

-- user_id カラム
SELECT COUNT(DISTINCT user_id) AS cardinality FROM orders;
-- 結果: 50,000種類
-- → カーディナリティ高い、インデックス効果大
```

**結論:**
- `user_id` にインデックス → ✅ 効果大
- `status` にインデックス → ❌ 効果薄い（ただし、他のカラムとの複合インデックスなら検討）

---

### Step 4: 複合インデックスの順序決定

#### 複合インデックスの基本

```sql
CREATE INDEX idx_orders ON orders(col1, col2, col3);
```

**ルール:**
- **左から順に使われる**
- 先頭のカラムがWHERE句にないと効かない

#### 使えるケース

```sql
-- インデックス: (col1, col2, col3)

WHERE col1 = 1                          -- ✅ 使える
WHERE col1 = 1 AND col2 = 2             -- ✅ 使える
WHERE col1 = 1 AND col2 = 2 AND col3 = 3 -- ✅ 使える
```

#### 使えないケース

```sql
-- インデックス: (col1, col2, col3)

WHERE col2 = 2                          -- ❌ 先頭がない
WHERE col3 = 3                          -- ❌ 先頭がない
WHERE col2 = 2 AND col3 = 3             -- ❌ 先頭がない
```

---

### 複合インデックスの順序ルール

#### ルール1: 等価条件 → 範囲条件の順

```sql
-- ❌ 悪い順序
CREATE INDEX idx_orders_bad ON orders(created_at, user_id);

SELECT * FROM orders
WHERE user_id = 123              -- 等価条件
  AND created_at >= '2024-01-01' -- 範囲条件
ORDER BY created_at DESC;

-- → created_at（範囲）が先頭にあるため、user_id（等価）が効かない
```

```sql
-- ✅ 良い順序
CREATE INDEX idx_orders_good ON orders(user_id, created_at);

SELECT * FROM orders
WHERE user_id = 123              -- 等価条件（先頭）
  AND created_at >= '2024-01-01' -- 範囲条件（後）
ORDER BY created_at DESC;

-- → user_id で絞り込み → created_at でソート
```

**理由:**
- 等価条件（`=`）で絞り込み → 範囲条件（`>=`, `BETWEEN`）で検索
- 範囲条件の後のカラムはインデックスが効きにくい

---

#### ルール2: カーディナリティが高い順

```sql
-- 例: orders テーブル
-- user_id: 50,000種類（カーディナリティ高）
-- status: 3種類（カーディナリティ低）

-- ❌ 悪い順序
CREATE INDEX idx_orders_bad ON orders(status, user_id);

-- ✅ 良い順序
CREATE INDEX idx_orders_good ON orders(user_id, status);
```

**理由:**
- カーディナリティが高い → 絞り込み効果大
- 先にデータを絞り込んでから、次の条件で検索

**ただし、例外:**
- **ルール1（等価 → 範囲）が優先**
- WHERE句で頻繁に使われる順（クエリパターンに依存）

---

#### ルール3: クエリパターンに合わせる

**クエリ1:**
```sql
SELECT * FROM orders
WHERE user_id = 123
  AND status = 'completed'
ORDER BY created_at DESC;
```

**最適なインデックス:**
```sql
CREATE INDEX idx_orders_user_status_date
ON orders(user_id, status, created_at);
```

**理由:**
1. `user_id` = 等価条件（先頭）
2. `status` = 等価条件
3. `created_at` = ORDER BY（ソート済み）

---

**クエリ2:**
```sql
SELECT * FROM orders
WHERE created_at >= '2024-01-01'
  AND status = 'completed';
```

**最適なインデックス:**
```sql
CREATE INDEX idx_orders_status_date
ON orders(status, created_at);
```

**理由:**
1. `status` = 等価条件（先頭）
2. `created_at` = 範囲条件（後）

---

### Step 5: 既存インデックスとの重複確認

#### 既存インデックスの確認

```sql
SHOW INDEX FROM orders;
```

**出力例:**
```
| Table  | Key_name        | Column_name | Seq_in_index |
|--------|-----------------|-------------|--------------|
| orders | PRIMARY         | id          | 1            |
| orders | idx_user_id     | user_id     | 1            |
| orders | idx_created_at  | created_at  | 1            |
```

---

#### 重複チェック

**ケース1: 完全に重複**
```sql
-- 既存
CREATE INDEX idx_user_id ON orders(user_id);

-- 新規提案
CREATE INDEX idx_new ON orders(user_id);  -- ❌ 完全重複
```

**対応:** 新規インデックスは不要

---

**ケース2: 部分的に重複（前方一致）**
```sql
-- 既存
CREATE INDEX idx_user_id ON orders(user_id);

-- 新規提案
CREATE INDEX idx_user_status ON orders(user_id, status);  -- ⚠️ 前方一致
```

**判断:**
- `idx_user_id` は `idx_user_status` に **包含される**
- **新規インデックスを作成し、既存インデックスを削除**する方が良い

**理由:**
- `idx_user_status` は `WHERE user_id = ?` にも使える
- インデックスが多いと、INSERT/UPDATE/DELETEが遅くなる

---

**ケース3: 順序が異なる**
```sql
-- 既存
CREATE INDEX idx_user_date ON orders(user_id, created_at);

-- 新規提案
CREATE INDEX idx_date_user ON orders(created_at, user_id);  -- ✅ 別物
```

**判断:**
- 順序が異なるため**別のインデックス**
- クエリパターンに応じて両方必要な場合がある

---

#### 統合の検討

**既存インデックス:**
```sql
CREATE INDEX idx_user_id ON orders(user_id);
CREATE INDEX idx_status ON orders(status);
```

**クエリパターン:**
```sql
-- パターン1
SELECT * FROM orders WHERE user_id = 123;

-- パターン2
SELECT * FROM orders WHERE status = 'completed';

-- パターン3（頻繁）
SELECT * FROM orders WHERE user_id = 123 AND status = 'completed';
```

**最適化案:**
```sql
-- 既存2つを削除
DROP INDEX idx_user_id ON orders;
DROP INDEX idx_status ON orders;

-- 複合インデックスを追加
CREATE INDEX idx_user_status ON orders(user_id, status);
```

**メリット:**
- パターン1: `idx_user_status` で対応（前方一致）
- パターン2: `status` のカーディナリティが低いため、元々効果薄い
- パターン3: `idx_user_status` で最適化

**注意:**
- パターン2が頻繁なら `idx_status` も残す

---

## 複合インデックスの順序ルール（まとめ）

### 優先順位

```
1位: 等価条件（=） → 範囲条件（>=, BETWEEN）
2位: カーディナリティが高い順
3位: クエリで頻繁に使われる順
```

### 実践例

**クエリ:**
```sql
SELECT * FROM orders
WHERE shop_id = 1              -- 等価、カーディナリティ: 中
  AND status = 'completed'     -- 等価、カーディナリティ: 低
  AND created_at >= '2024-01-01'  -- 範囲、カーディナリティ: 高
ORDER BY created_at DESC;
```

**判断:**

| カラム | 条件タイプ | カーディナリティ | 順序 |
|--------|----------|----------------|------|
| shop_id | 等価 | 中 | 1位 or 2位 |
| status | 等価 | 低 | 2位 or 3位 |
| created_at | 範囲 | 高 | 最後 |

**最適なインデックス:**
```sql
-- 方法1: shop_id が頻繁に使われる場合
CREATE INDEX idx_orders_shop_status_date
ON orders(shop_id, status, created_at);

-- 方法2: status との組み合わせが頻繁な場合
CREATE INDEX idx_orders_status_shop_date
ON orders(status, shop_id, created_at);
```

**ルール適用:**
1. 等価条件を先頭に（shop_id, status）
2. 範囲条件を最後に（created_at）
3. 等価条件間はカーディナリティ or 頻度で決定

---

## インデックスを張るべき/張るべきでないケース

### 張るべきケース

| ケース | 理由 | 例 |
|--------|------|---|
| **PRIMARY KEY / UNIQUE KEY** | 一意性保証、検索高速化 | `users.id`, `users.email` |
| **外部キー（JOIN条件）** | 結合で頻繁に使われる | `orders.user_id` |
| **WHERE句で頻繁に使われる** | 絞り込み高速化 | `users.email`, `orders.status` |
| **ORDER BY句で使われる** | ソート高速化（filesort回避） | `orders.created_at` |
| **カーディナリティが高い** | 絞り込み効果大 | `orders.order_id` |
| **選択率が低い（5〜10%以下）** | フルスキャンより高速 | `WHERE created_at >= '2024-01-01'`（全体の1%） |

---

### 張るべきでないケース

| ケース | 理由 | 例 |
|--------|------|---|
| **カーディナリティが低い** | 絞り込み効果薄い | `gender`（M/F）, `is_deleted`（0/1） |
| **選択率が高い（50%以上）** | フルスキャンの方が速い | `WHERE is_active = 1`（90%がactive） |
| **頻繁に更新される列** | INSERT/UPDATE/DELETEが遅くなる | `updated_at` |
| **既存インデックスと重複** | メンテナンスコスト増 | `(user_id)` と `(user_id, status)` |
| **テーブルが小さい** | インデックスの恩恵なし | 100行以下のマスタテーブル |
| **インデックスが効かない条件** | 使われないインデックスは無駄 | `WHERE YEAR(created_at) = 2024` |

**参照:** [knowledge/index-strategies.md](../knowledge/index-strategies.md#インデックスが効かない5パターン)

---

### 例外: 複合インデックスなら効く場合

カーディナリティが低い列でも、**複合インデックスの一部**なら効果的。

**例:**
```sql
-- 単独では効果薄い
CREATE INDEX idx_status ON orders(status);  -- ❌ カーディナリティ低い

-- 複合インデックスなら効果的
CREATE INDEX idx_user_status ON orders(user_id, status);  -- ✅
```

**クエリ:**
```sql
SELECT * FROM orders
WHERE user_id = 123          -- user_id で絞り込み（50,000 → 20行）
  AND status = 'completed';  -- status でさらに絞り込み（20 → 5行）
```

**理由:**
- `user_id` で大幅に絞り込み
- その後、`status` で追加フィルタリング
- カーディナリティが低くても効果あり

---

## 出力フォーマット

### 提案するインデックスのテンプレート

```markdown
## インデックス提案

### 1. [テーブル名].[インデックス名]

**対象クエリ:**
\```sql
[最適化対象のクエリ]
\```

**CREATE INDEX文:**
\```sql
CREATE INDEX [インデックス名] ON [テーブル名]([カラム1], [カラム2], ...);
\```

**理由:**
- [ ] WHERE句で使われるカラム: `[カラム名]`
- [ ] JOIN条件で使われるカラム: `[カラム名]`
- [ ] ORDER BY句で使われるカラム: `[カラム名]`
- [ ] カーディナリティ: [高/中/低]
- [ ] 選択率: [X%]
- [ ] 複合インデックスの順序: [理由]

**期待される効果:**
- type: ALL → range/ref
- rows: [削減前] → [削減後]
- Extra: Using filesort → Using index

**既存インデックスとの関係:**
- [ ] 新規追加
- [ ] `[既存インデックス名]` と統合
- [ ] `[既存インデックス名]` を削除
```

---

### 実践例

#### 例1: 単一カラムインデックス

```markdown
## インデックス提案

### 1. users.idx_email

**対象クエリ:**
\```sql
SELECT * FROM users WHERE email = 'user@example.com';
\```

**CREATE INDEX文:**
\```sql
CREATE INDEX idx_email ON users(email);
\```

**理由:**
- [x] WHERE句で使われるカラム: `email`
- [x] カーディナリティ: 高（ユーザー数と同じ）
- [x] 選択率: 0.0001%（1件/100万件）
- [x] 頻繁に実行されるクエリ（ログイン時）

**期待される効果:**
- type: ALL → const
- rows: 1,000,000 → 1
- 推定実行時間: 500ms → 5ms（100倍高速化）

**既存インデックスとの関係:**
- [x] 新規追加
```

---

#### 例2: 複合インデックス

```markdown
## インデックス提案

### 1. orders.idx_user_status_date

**対象クエリ:**
\```sql
SELECT * FROM orders
WHERE user_id = 123
  AND status = 'completed'
ORDER BY created_at DESC
LIMIT 10;
\```

**CREATE INDEX文:**
\```sql
CREATE INDEX idx_user_status_date ON orders(user_id, status, created_at);
\```

**理由:**
- [x] WHERE句で使われるカラム: `user_id`, `status`
- [x] ORDER BY句で使われるカラム: `created_at`
- [x] カーディナリティ: user_id（高）, status（低）, created_at（高）
- [x] 複合インデックスの順序:
  1. `user_id` - 等価条件、カーディナリティ高
  2. `status` - 等価条件、カーディナリティ低
  3. `created_at` - ORDER BY、ソート回避

**期待される効果:**
- type: ALL → ref
- rows: 1,000,000 → 20
- Extra: Using filesort → Using index（ソート不要）
- 推定実行時間: 2000ms → 10ms（200倍高速化）

**既存インデックスとの関係:**
- [x] 既存の `idx_user_id` を削除
- [x] 新規の `idx_user_status_date` に統合
```

---

#### 例3: カバリングインデックス

```markdown
## インデックス提案

### 1. orders.idx_user_id_created_at_amount

**対象クエリ:**
\```sql
SELECT user_id, created_at, amount
FROM orders
WHERE user_id = 123
ORDER BY created_at DESC;
\```

**CREATE INDEX文:**
\```sql
CREATE INDEX idx_user_id_created_at_amount
ON orders(user_id, created_at, amount);
\```

**理由:**
- [x] WHERE句で使われるカラム: `user_id`
- [x] ORDER BY句で使われるカラム: `created_at`
- [x] SELECT句で使われるカラム: `user_id`, `created_at`, `amount`
- [x] カバリングインデックス: テーブル本体にアクセス不要

**期待される効果:**
- type: ref → ref
- Extra: NULL → **Using index**（カバリングインデックス）
- テーブル本体へのアクセス: 削減
- 推定実行時間: 50ms → 10ms（5倍高速化）

**既存インデックスとの関係:**
- [x] 既存の `idx_user_created` を拡張
```

---

## インデックス設計のチェックリスト

### 設計前
- [ ] スロークエリログを確認
- [ ] 頻繁に実行されるクエリを特定
- [ ] WHERE/JOIN/ORDER BY句のカラムを洗い出し

### 設計中
- [ ] カーディナリティを確認（`COUNT(DISTINCT column)`）
- [ ] 選択率を確認（5〜10%以下が目安）
- [ ] 複合インデックスの順序を決定（等価 → 範囲、カーディナリティ高 → 低）
- [ ] 既存インデックスとの重複をチェック

### 設計後
- [ ] EXPLAIN で実行計画を確認
- [ ] type が ALL → ref/range に改善されるか
- [ ] rows が削減されるか
- [ ] Extra で Using filesort/temporary が消えるか
- [ ] 統合・削除すべき既存インデックスを特定

### 運用
- [ ] インデックスの使用状況を監視
- [ ] 使われていないインデックスを削除
- [ ] データ量増加に応じて再評価

---

## よくある質問

### Q1: インデックスはいくつまで作れる？

**A:** 技術的には無制限だが、**多すぎるとINSERT/UPDATE/DELETEが遅くなる**

**推奨:**
- 1テーブルあたり **5〜10個以内**
- 頻繁に更新されるテーブルは **3〜5個以内**

---

### Q2: 複合インデックスは何カラムまで？

**A:** 技術的には16カラムまで可能だが、**3〜4カラム以内が実用的**

**理由:**
- カラムが多いとインデックスサイズが大きくなる
- メンテナンスコスト増加

---

### Q3: PRIMARY KEYにインデックスは必要？

**A:** **不要**。PRIMARY KEYは自動的にインデックスが作成される

```sql
-- これだけでOK
CREATE TABLE users (
    id INT PRIMARY KEY,
    name VARCHAR(255)
);

-- 自動的に idx_PRIMARY が作成される
```

---

### Q4: NULL値が多い列にインデックスは効く？

**A:** **DBMSによる**

- **MySQL（InnoDB）**: NULL値もインデックスに含まれる → `IS NULL` でも効く
- **Oracle**: NULL値はインデックスに含まれない → `IS NULL` では効かない

**推奨:**
- NULL値が多い列は避ける
- デフォルト値を設定する

---

### Q5: インデックスを張ったのに使われない

**A:** 以下を確認

1. **インデックスが効かない条件ではないか**
   - `LIKE '%keyword%'`（中間一致）
   - `WHERE YEAR(date) = 2024`（列を加工）
   - `WHERE col <> 'value'`（否定形）

2. **統計情報が古い**
   ```sql
   ANALYZE TABLE table_name;
   ```

3. **選択率が高い（50%以上）**
   - オプティマイザがフルスキャンを選択

4. **複合インデックスの順序が間違っている**
   - WHERE句の条件がインデックスの先頭カラムから使われているか確認

**参照:** [knowledge/index-strategies.md](../knowledge/index-strategies.md#インデックスが効かない5パターン)

---

## 参考リンク

- [knowledge/index-strategies.md](../knowledge/index-strategies.md) - インデックス戦略詳細
- [knowledge/anti-patterns.md](../knowledge/anti-patterns.md) - アンチパターン集
- [tasks/read-execution-plan.md](./read-execution-plan.md) - 実行計画の読み方
- [tasks/diagnose-slow-query.md](./diagnose-slow-query.md) - 遅いクエリの診断
- [tasks/review-query.md](./review-query.md) - SQLクエリレビュー
