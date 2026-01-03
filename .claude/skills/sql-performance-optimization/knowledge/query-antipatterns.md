# クエリアンチパターン集

## Spaghetti Query（スパゲッティクエリ）

### 概要
1つのクエリで複数の目的を達成しようとして、複雑で理解困難なクエリになってしまうアンチパターン。意図しないデカルト積が発生し、DISTINCTで誤魔化そうとする。

### 問題のパターン

#### パターン1: 複数の目的を1クエリで達成
```sql
-- ❌ 悪い例: 商品とレビューとタグを1つのクエリで取得
SELECT DISTINCT
    p.product_id,
    p.product_name,
    r.review_text,
    t.tag_name
FROM Products p
LEFT JOIN Reviews r ON p.product_id = r.product_id
LEFT JOIN ProductTags pt ON p.product_id = pt.product_id
LEFT JOIN Tags t ON pt.tag_id = t.tag_id
WHERE p.category = 'Electronics';
```

**問題点:**
- **意図しないデカルト積**: 商品1つに対して、レビュー3件×タグ2件 = 6行返る
- **DISTINCTで誤魔化す**: 重複行を削除するためのコスト
- **複雑で理解困難**: 何を取得したいのか不明確
- **将来の変更が困難**: 新しいテーブルを追加すると爆発的に複雑化

**EXPLAIN結果:**
```
-> Filter: (p.category = 'Electronics')
    -> Nested loop left join  (rows=600)  ← デカルト積
        -> Nested loop left join  (rows=100)
            -> Table scan on p
            -> Index lookup on r
        -> Index lookup on pt → さらに結合
```

### 解決策: クエリを分割する

#### 方法1: 複数クエリに分割
```sql
-- ✅ 良い例1: 商品情報
SELECT product_id, product_name
FROM Products
WHERE category = 'Electronics';

-- ✅ 良い例2: レビュー（アプリケーション側で取得）
SELECT review_text
FROM Reviews
WHERE product_id = ?;

-- ✅ 良い例3: タグ（アプリケーション側で取得）
SELECT tag_name
FROM ProductTags pt
JOIN Tags t ON pt.tag_id = t.tag_id
WHERE pt.product_id = ?;
```

**メリット:**
- 各クエリの目的が明確
- デカルト積が発生しない
- 保守性が高い
- 必要なデータだけ取得
- パフォーマンスが良い（必要なクエリだけ実行）

**原則:** 複数の目的があるなら、複数のクエリに分割する

### 検出方法

#### チェックポイント
- [ ] **複数のLEFT JOINがあるか？**
  - 3つ以上のLEFT JOINは要注意
  - 多対多の関係が含まれるか

- [ ] **DISTINCTを使っているか？**
  - なぜ重複が発生するのか理解しているか
  - デカルト積が原因ではないか

- [ ] **EXPLAINのrows が異常に大きいか？**
  - 各テーブルのrows を掛け算すると推定検査行数
  - 実際の結果行数より大きければデカルト積の可能性

- [ ] **1クエリで複数の目的を達成しようとしているか？**
  - 「商品情報 + レビュー + タグ」のように
  - 分割できないか検討

#### 判断フロー
```
複数のLEFT JOINがある？
├─ YES → 多対多の関係が含まれる？
│        ├─ YES → デカルト積のリスク → クエリ分割検討
│        └─ NO  → 問題なし
│
└─ NO  → 問題なし

DISTINCTを使っている？
├─ YES → なぜ重複が発生？
│        ├─ デカルト積 → クエリ分割検討
│        └─ その他 → 原因を理解して使う
│
└─ NO  → 問題なし
```

---

## Ambiguous Groups（曖昧なグループ）

### 概要
GROUP BY句に含まれない列をSELECT句で参照する問題。Single-Value Ruleに違反し、結果が不定になる。

### 問題のパターン

```sql
-- ❌ 悪い例: GROUP BYに含まれない列をSELECT
SELECT
    bug_id,        -- ← GROUP BYに含まれていない
    product_id,    -- ← GROUP BYのキー
    MAX(date_reported) AS latest
FROM Bugs
GROUP BY product_id;
```

**問題点:**
- **Single-Value Rule違反**: GROUP BYの各グループに対して、bug_idは複数の値がありうる
- **結果が不定**: どのbug_idが返るか保証されない（DBMSの実装依存）
- **MySQLのデフォルト動作**: MySQL 5.7まではエラーにならず、不定な値を返す
- **MySQL 8.0以降**: `ONLY_FULL_GROUP_BY`モードがデフォルトでエラーになる

**実際の動作例:**
```
product_id=1のグループに以下のbug_idがある場合:
  bug_id: 1234, 1235, 1236
→ どのbug_idが返るか不定（1234かもしれないし1235かもしれない）
```

### Single-Value Rule（単一値ルール）

**定義:**
GROUP BY句の各グループに対して、SELECT句の各カラムは**単一の値**でなければならない。

**OK:**
- GROUP BYに含まれる列
- 集約関数（MAX、MIN、COUNT、SUM、AVG）
- 機能的従属がある列（主キーでGROUP BYしている場合、その表の他の列は自動的に単一値）

**NG:**
- GROUP BYに含まれない列を直接SELECT

### 解決策

#### 方法1: 集約関数を使う
```sql
-- ✅ 良い例1: MAXでbug_idを取得
SELECT
    MAX(bug_id) AS latest_bug_id,  -- 集約関数を使う
    product_id,
    MAX(date_reported) AS latest
FROM Bugs
GROUP BY product_id;
```

**注意:** MAXは「最新のバグID」を保証しない（最大値を取るだけ）

#### 方法2: GROUP BYに含める
```sql
-- ✅ 良い例2: 全ての列をGROUP BYに含める
SELECT
    bug_id,
    product_id,
    date_reported
FROM Bugs
GROUP BY bug_id, product_id, date_reported;
```

**注意:** これは実質GROUP BYの意味がない（全列でグループ化 = DISTINCT相当）

#### 方法3: サブクエリで最新の行を特定
```sql
-- ✅ 良い例3: サブクエリで最新日時を特定 → 結合
SELECT b.bug_id, b.product_id, b.date_reported
FROM Bugs b
INNER JOIN (
    SELECT product_id, MAX(date_reported) AS latest
    FROM Bugs
    GROUP BY product_id
) b2
ON b.product_id = b2.product_id
AND b.date_reported = b2.latest;
```

#### 方法4: ウィンドウ関数を使う（推奨）
```sql
-- ✅ 良い例4: ROW_NUMBERで最新行を取得
SELECT bug_id, product_id, date_reported
FROM (
    SELECT
        bug_id,
        product_id,
        date_reported,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY date_reported DESC
        ) AS rn
    FROM Bugs
) ranked
WHERE rn = 1;
```

**メリット:**
- 1回のテーブルスキャン
- 意図が明確
- パフォーマンスが良い

### 検出方法

#### MySQLで検出
```sql
-- ONLY_FULL_GROUP_BYモードを有効化
SET sql_mode = 'ONLY_FULL_GROUP_BY';

-- エラーになる場合、Single-Value Rule違反
SELECT bug_id, product_id, MAX(date_reported)
FROM Bugs
GROUP BY product_id;
-- ERROR 1055: 'bug_id' isn't in GROUP BY
```

#### チェックポイント
- [ ] **SELECT句の全ての列が以下のいずれかか？**
  - GROUP BYに含まれる
  - 集約関数（MAX、MIN、COUNT、SUM、AVG）
  - 主キーでGROUP BYしている場合の従属列

- [ ] **意図した結果が返っているか？**
  - 不定な値が返っていないか
  - テストデータで確認

---

## Implicit Columns（暗黙の列）

### 概要
`SELECT *` を使うことで、意図しない列の取得やスキーマ変更時の問題が発生するアンチパターン。

### 問題のパターン

```sql
-- ❌ 悪い例: SELECT *
SELECT * FROM Users;
```

**問題点:**

#### 1. スキーマ変更で壊れる
```sql
-- 当初のテーブル
CREATE TABLE Users (id, name, email);

-- アプリケーション側で列順序を想定
result[0] = id
result[1] = name
result[2] = email

-- 後で列を追加
ALTER TABLE Users ADD COLUMN created_at TIMESTAMP AFTER id;

-- 列順序が変わる
result[0] = id
result[1] = created_at  ← 想定外
result[2] = name        ← 想定外
result[3] = email       ← 想定外

→ バグが発生
```

#### 2. 不要な列の取得によるI/O増加
```sql
-- ❌ 悪い例: 実際にはidとnameしか使わないのに全列取得
SELECT * FROM Users WHERE status = 'active';

-- カラム: id, name, email, address, phone, created_at, updated_at, profile_image (BLOB)
→ 不要な大きいカラム（profile_image）まで取得してI/O増加
```

#### 3. カバリングインデックスが効かない
```sql
-- インデックス: idx(status, id, name)

-- ❌ 悪い例: SELECT *
SELECT * FROM Users WHERE status = 'active';
→ インデックスだけでは完結できない → テーブル本体にアクセス

-- ✅ 良い例: 必要な列だけ
SELECT id, name FROM Users WHERE status = 'active';
→ インデックスだけで完結（カバリングインデックス）
```

**EXPLAIN比較:**
```
-- SELECT *
Extra: Using where

-- SELECT id, name
Extra: Using where; Using index  ← カバリングインデックス
```

#### 4. 結合時に列名が衝突
```sql
-- ❌ 悪い例: 両方のテーブルにidが存在
SELECT *
FROM Users u
JOIN Orders o ON u.id = o.user_id;

→ 結果にid列が2つ（どちらがどちらか不明）
```

### 解決策: 必要な列を明示する

```sql
-- ✅ 良い例1: 必要な列だけ明示
SELECT id, name, email
FROM Users
WHERE status = 'active';
```

**メリット:**
- スキーマ変更に強い（列を追加しても影響なし）
- I/Oが最小限
- カバリングインデックスの恩恵
- 意図が明確

```sql
-- ✅ 良い例2: 結合時はテーブル別名を使う
SELECT
    u.id AS user_id,
    u.name,
    o.id AS order_id,
    o.total
FROM Users u
JOIN Orders o ON u.id = o.user_id;
```

**メリット:**
- 列名の衝突を回避
- どのテーブルの列か明確

### 例外: SELECT * が許容されるケース

#### ケース1: サブクエリで全列が必要
```sql
-- サブクエリで絞り込んだ後、全列を返す
SELECT * FROM (
    SELECT id, name, email, status
    FROM Users
    WHERE created_at >= '2024-01-01'
) recent_users
WHERE status = 'active';
```

#### ケース2: アドホッククエリ（調査・デバッグ）
```sql
-- 調査目的で全列を確認
SELECT * FROM Users WHERE id = 12345;
```

→ 本番コードでは使わない

### 検出方法

#### チェックポイント
- [ ] **本番コードでSELECT * を使っていないか？**
  - ORM生成のクエリは除く（ただしORM設定で必要列だけfetchするのが望ましい）

- [ ] **カバリングインデックスの機会を逃していないか？**
  - WHERE句の列にインデックスがある場合、SELECT句も同じインデックスに含めることで高速化

- [ ] **大きいカラム（BLOB、TEXT等）を含むテーブルか？**
  - SELECT * で不要な大きいカラムを取得していないか

---

## Poor Man's Search Engine（貧者のサーチエンジン）

### 概要
`LIKE '%keyword%'` によるパターンマッチで全文検索を実現しようとするアンチパターン。インデックスが効かず、意図しないマッチも発生する。

### 問題のパターン

```sql
-- ❌ 悪い例: LIKE中間一致
SELECT * FROM Products
WHERE description LIKE '%camera%';
```

**問題点:**

#### 1. インデックスが効かない
```
インデックスは「先頭からの一致」しか使えない

✅ 'camera%'  → インデックス使える
❌ '%camera'  → インデックス使えない（後方一致）
❌ '%camera%' → インデックス使えない（中間一致）

→ テーブル全件スキャン
```

**EXPLAIN結果:**
```
type: ALL          ← フルテーブルスキャン
key: NULL          ← インデックス未使用
rows: 1000000      ← 全行スキャン
Extra: Using where
```

#### 2. 意図しないマッチ
```sql
-- 「one」を検索したつもりが...
SELECT * FROM Products
WHERE name LIKE '%one%';

-- 意図しないマッチ:
→ 'iPhone'     ← 'one'を含む
→ 'money'      ← 'one'を含む
→ 'bone china' ← 'one'を含む
```

#### 3. パフォーマンス劣化
```
1,000,000行のテーブルで検索:
  LIKE '%camera%': 全行スキャン → 数秒〜数十秒
  FULLTEXT検索:    インデックス使用 → 数ミリ秒
```

### 解決策

#### 方法1: 全文検索インデックス（MySQL FULLTEXT）

##### 1. FULLTEXTインデックス作成
```sql
-- ✅ FULLTEXTインデックス作成
CREATE FULLTEXT INDEX ft_description ON Products(description);
```

##### 2. MATCH AGAINST で検索
```sql
-- ✅ 良い例: MATCH AGAINST
SELECT * FROM Products
WHERE MATCH(description) AGAINST('camera' IN NATURAL LANGUAGE MODE);
```

**メリット:**
- インデックスを使った高速検索
- 関連度順にソート可能
- ストップワード除外（'the', 'a'等）
- 語幹処理（stemming）

##### 3. ブーリアンモード（AND, OR, NOT）
```sql
-- 'camera'を含むが'digital'は含まない
SELECT * FROM Products
WHERE MATCH(description) AGAINST('+camera -digital' IN BOOLEAN MODE);

-- 'camera'または'video'を含む
SELECT * FROM Products
WHERE MATCH(description) AGAINST('camera video' IN BOOLEAN MODE);
```

##### 4. 関連度スコア取得
```sql
-- 関連度の高い順にソート
SELECT
    product_id,
    name,
    MATCH(description) AGAINST('camera') AS relevance
FROM Products
WHERE MATCH(description) AGAINST('camera')
ORDER BY relevance DESC;
```

#### 方法2: 前方一致に変更（可能な場合）
```sql
-- ✅ 良い例: 前方一致ならインデックスが効く
SELECT * FROM Products
WHERE name LIKE 'iPhone%';
```

**EXPLAIN結果:**
```
type: range        ← インデックス範囲検索
key: idx_name      ← インデックス使用
rows: 100          ← 絞り込まれた行数
```

#### 方法3: 専用の全文検索エンジン（大規模システム）
- **Elasticsearch**: 高機能な全文検索・分析エンジン
- **Apache Solr**: オープンソース検索プラットフォーム

**適用ケース:**
- 大量のテキストデータ（数百万〜数億件）
- 高度な検索機能が必要（ファセット、ハイライト、スペルチェック等）
- 高速な検索が必須

### MySQL FULLTEXTインデックスの制約

#### 最小単語長（MySQL）
```sql
-- デフォルトで3文字未満の単語は無視される
SHOW VARIABLES LIKE 'ft_min_word_len';
-- ft_min_word_len = 3

-- 「AI」「IT」は検索できない（2文字）
SELECT * FROM Products
WHERE MATCH(description) AGAINST('AI');
→ ヒットしない

-- 設定変更（my.cnf）
ft_min_word_len = 2
-- 再起動 + インデックス再構築が必要
```

#### 日本語検索（N-gram）
```sql
-- MySQL 5.7.6+ でN-gramサポート
CREATE FULLTEXT INDEX ft_description ON Products(description)
WITH PARSER ngram;

-- 日本語でも検索可能
SELECT * FROM Products
WHERE MATCH(description) AGAINST('カメラ');
```

### 検出方法

#### チェックポイント
- [ ] **LIKE '%keyword%' を使っているか？**
  - 前方一致に変更できないか
  - FULLTEXTインデックスが使えないか

- [ ] **検索対象のテーブルが大きいか？**
  - 1万行未満: LIKE でも許容されることが多い
  - 10万行以上: FULLTEXT推奨
  - 100万行以上: FULLTEXT必須

- [ ] **頻繁に検索されるか？**
  - 頻繁 → FULLTEXT推奨
  - たまに → LIKE でも許容

#### 判断フロー
```
LIKE '%keyword%' を使っている？
├─ YES → テーブルサイズは？
│        ├─ 大（10万行以上） → FULLTEXTインデックス検討
│        └─ 小（1万行未満）  → 許容される場合も
│
└─ NO  → 前方一致（'keyword%'）か？
         ├─ YES → インデックスが効く → OK
         └─ NO  → OK
```

---

## Random Selection（ランダムセレクション）

### 概要
`ORDER BY RAND()` でランダムな行を取得しようとするアンチパターン。全行にランダム値を付与してソートするため非常に遅い。

### 問題のパターン

```sql
-- ❌ 悪い例: ORDER BY RAND()
SELECT * FROM Products
ORDER BY RAND()
LIMIT 1;
```

**問題点:**

#### 1. 全行にランダム値を付与 → ソート
```
動作:
1. 全行（100万行）にRAND()で乱数を付与
2. 100万行をソート
3. 上位1行を返す

→ 1行だけ欲しいのに100万行を処理
```

**EXPLAIN結果:**
```
type: ALL                          ← 全行スキャン
rows: 1000000                      ← 全行処理
Extra: Using temporary; Using filesort  ← 一時テーブル作成 + ソート
```

#### 2. パフォーマンス
```
テーブルサイズ別の実行時間（目安）:
  1,000行:     0.01秒
  10,000行:    0.1秒
  100,000行:   1秒
  1,000,000行: 10秒〜
```

#### 3. 再現性がない
```sql
-- 同じクエリを実行しても毎回異なる結果
SELECT * FROM Products ORDER BY RAND() LIMIT 1;
→ product_id = 123

SELECT * FROM Products ORDER BY RAND() LIMIT 1;
→ product_id = 456

-- テスト・デバッグが困難
```

### 解決策

#### 方法1: 行数取得 → アプリでランダムオフセット生成 → LIMIT（推奨）

##### ステップ1: 行数を取得
```sql
-- 行数を取得（高速）
SELECT COUNT(*) AS total FROM Products;
-- total = 100000
```

##### ステップ2: アプリケーション側でランダムオフセット生成
```javascript
// JavaScript例
const total = 100000;
const randomOffset = Math.floor(Math.random() * total);
// randomOffset = 42567
```

##### ステップ3: OFFSETで取得
```sql
-- ✅ 良い例: OFFSETで直接アクセス
SELECT * FROM Products
LIMIT 1 OFFSET 42567;
```

**メリット:**
- 全行スキャン不要
- ソート不要
- 高速（1行だけアクセス）

**EXPLAIN結果:**
```
type: ALL
rows: 42568  ← OFFSETまでスキャン
Extra: Using where
```

**注意点:**
- OFFSETが大きいと遅い（42568行スキャン）
- 次の方法2がより高速

#### 方法2: 主キーの範囲からランダム選択（最速）

##### ステップ1: 主キーの最小値・最大値を取得
```sql
-- 最小値・最大値を取得
SELECT MIN(id) AS min_id, MAX(id) AS max_id
FROM Products;
-- min_id = 1, max_id = 150000
```

##### ステップ2: アプリケーション側でランダムID生成
```javascript
// JavaScript例
const minId = 1;
const maxId = 150000;
const randomId = Math.floor(Math.random() * (maxId - minId + 1)) + minId;
// randomId = 87345
```

##### ステップ3: 主キーで取得
```sql
-- ✅ 良い例: 主キーで直接アクセス（最速）
SELECT * FROM Products
WHERE id >= 87345
ORDER BY id
LIMIT 1;
```

**メリット:**
- インデックス使用（主キー）
- 1行だけアクセス
- 超高速

**EXPLAIN結果:**
```
type: range       ← インデックス範囲検索
key: PRIMARY      ← 主キー使用
rows: 1           ← 1行だけアクセス
Extra: Using where
```

**注意点:**
- 主キーに歯抜けがある場合、存在しないIDが生成される可能性
  → 見つかるまでリトライ or `WHERE id >= ? LIMIT 1` で次の行を取得

#### 方法3: 複数行ランダム取得（方法1の応用）

```javascript
// 10行ランダム取得
const total = 100000;
const limit = 10;
const randomOffset = Math.floor(Math.random() * (total - limit));

// SQL
SELECT * FROM Products
LIMIT 10 OFFSET ${randomOffset};
```

#### 方法4: ランダムシード固定（再現性が必要な場合）

```sql
-- ✅ シード固定でランダム順序が再現可能
SELECT * FROM Products
ORDER BY RAND(12345)  -- シード固定
LIMIT 10;

-- 同じシードなら同じ順序
```

**用途:**
- A/Bテスト
- デモ環境で同じデータを表示

### パフォーマンス比較

| 方法 | 実行時間（100万行） | EXPLAIN |
|---|---|---|
| ORDER BY RAND() | 10秒〜 | type=ALL, rows=1000000, Using filesort |
| OFFSET方式 | 0.1秒 | type=ALL, rows=50000（平均） |
| 主キー範囲方式 | 0.001秒 | type=range, rows=1, Using index |

### 検出方法

#### チェックポイント
- [ ] **ORDER BY RAND() を使っているか？**
  - 行数取得 → アプリでオフセット生成 に変更できないか
  - 主キー範囲方式が使えないか

- [ ] **テーブルが大きいか？**
  - 1,000行未満: ORDER BY RAND() でも許容
  - 10,000行以上: 代替方法検討
  - 100,000行以上: 代替方法必須

- [ ] **頻繁に実行されるか？**
  - 頻繁 → 代替方法必須
  - たまに（管理画面等） → ORDER BY RAND() でも許容

#### 判断フロー
```
ORDER BY RAND() を使っている？
├─ YES → テーブルサイズは？
│        ├─ 大（10万行以上） → 代替方法必須
│        │                     1. 行数取得 → OFFSET方式
│        │                     2. 主キー範囲方式（推奨）
│        │
│        └─ 小（1万行未満）  → 許容される場合も
│
└─ NO  → OK
```

---

## まとめ

### アンチパターン早見表

| アンチパターン | 問題 | 解決策 |
|---|---|---|
| **Spaghetti Query** | 1クエリで複数目的、デカルト積 | クエリ分割、JSON集約 |
| **Ambiguous Groups** | GROUP BY違反、Single-Value Rule | 集約関数、ウィンドウ関数 |
| **Implicit Columns** | SELECT *、スキーマ変更で壊れる | 必要な列を明示 |
| **Poor Man's Search Engine** | LIKE '%keyword%'、インデックス効かない | FULLTEXTインデックス |
| **Random Selection** | ORDER BY RAND()、全行ソート | 行数取得→OFFSET、主キー範囲 |

### 共通の教訓

1. **シンプルに保つ**: 1クエリ1目的
2. **インデックスを活用**: LIKE前方一致、FULLTEXT
3. **全行スキャンを避ける**: WHERE句で絞り込み
4. **EXPLAIN で確認**: 推測せず、実行計画で検証
5. **スケーラビリティを考慮**: 少量データでは問題なくても、大量データで破綻しないか

---

## 参考資料

- O'Reilly「SQLアンチパターン」(oreilly-978-4-8144-0074-4e)
- [knowledge/anti-patterns.md](./anti-patterns.md) - 既存アンチパターン
- [knowledge/index-strategies.md](./index-strategies.md) - インデックス戦略
- [tasks/review-query.md](../tasks/review-query.md) - クエリレビューチェックリスト
