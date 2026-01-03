# 論理設計アンチパターン集

## Jaywalking（ジェイウォーク）

### 概要
カンマ区切りのリストをVARCHAR列に格納するアンチパターン。リレーショナルデータベースの基本原則「第1正規形」に違反する。

### 問題のパターン

```sql
-- ❌ 悪い例: カンマ区切りで複数のタグを格納
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255),
    tags VARCHAR(1000)  -- 'electronics,smartphone,5g'
);

INSERT INTO Products VALUES
(1, 'iPhone 15', 'electronics,smartphone,5g'),
(2, 'MacBook Pro', 'electronics,laptop,m3'),
(3, 'AirPods Pro', 'electronics,audio,anc');
```

**問題点:**

#### 1. 検索でインデックスが効かない
```sql
-- 'smartphone'タグの商品を検索したい
SELECT * FROM Products
WHERE tags LIKE '%smartphone%';
```

- フルテーブルスキャン（インデックス無効）
- 意図しない false positive（'smartphone_case'も引っかかる）

#### 2. 集計が困難
```sql
-- タグごとの商品数を集計したい
-- → SQLでは困難（アプリケーション側で分解が必要）
```

#### 3. JOIN が複雑
```sql
-- 特定のタグに関連する商品を JOIN したい
-- → 不可能（外部キーが使えない）
```

#### 4. データ整合性を保証できない
- typo（'smatphone'）を防げない
- 削除されたタグが残る
- 重複を防げない（'electronics,electronics'）

#### 5. 値の追加・削除が複雑
```sql
-- 'waterproof'タグを追加したい
UPDATE Products
SET tags = CONCAT(tags, ',waterproof')
WHERE product_id = 1;
-- → 末尾にカンマが付く問題、重複チェックが必要
```

### 解決策: 交差テーブル（中間テーブル）を使う

```sql
-- ✅ 良い例: 正規化されたテーブル設計
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255)
);

CREATE TABLE Tags (
    tag_id INT PRIMARY KEY,
    tag_name VARCHAR(50) UNIQUE
);

CREATE TABLE ProductTags (
    product_id INT,
    tag_id INT,
    PRIMARY KEY (product_id, tag_id),
    FOREIGN KEY (product_id) REFERENCES Products(product_id),
    FOREIGN KEY (tag_id) REFERENCES Tags(tag_id)
);

-- データ挿入
INSERT INTO Products VALUES (1, 'iPhone 15');
INSERT INTO Tags VALUES (1, 'electronics'), (2, 'smartphone'), (3, '5g');
INSERT INTO ProductTags VALUES (1, 1), (1, 2), (1, 3);
```

**メリット:**

#### 1. 検索が高速（インデックス使用）
```sql
-- 'smartphone'タグの商品を検索
SELECT p.*
FROM Products p
JOIN ProductTags pt ON p.product_id = pt.product_id
JOIN Tags t ON pt.tag_id = t.tag_id
WHERE t.tag_name = 'smartphone';

-- インデックスが効く
CREATE INDEX idx_tag_name ON Tags(tag_name);
```

#### 2. 集計が簡単
```sql
-- タグごとの商品数
SELECT t.tag_name, COUNT(*) AS product_count
FROM Tags t
JOIN ProductTags pt ON t.tag_id = pt.tag_id
GROUP BY t.tag_name;
```

#### 3. データ整合性を保証
- 外部キー制約で存在しないタグIDを防ぐ
- `tag_name UNIQUE`で重複を防ぐ
- 削除時にカスケード制御可能

#### 4. 値の追加・削除が簡単
```sql
-- タグ追加
INSERT INTO ProductTags VALUES (1, 4);  -- product_id=1 に tag_id=4 を追加

-- タグ削除
DELETE FROM ProductTags
WHERE product_id = 1 AND tag_id = 3;
```

### 検出方法

#### チェックポイント
- [ ] **VARCHAR列にカンマ区切りデータが入っていないか？**
  - 列名に `_list`, `_tags`, `_ids` が含まれる
  - サンプルデータにカンマが含まれる

- [ ] **多対多の関係を1列で表現しようとしていないか？**
  - 「1つの商品に複数のタグ」のような関係

- [ ] **LIKE '%keyword%' で検索しているか？**
  - カンマ区切りデータを検索するクエリ

---

## EAV（エンティティ・アトリビュート・バリュー）

### 概要
汎用的な属性テーブル（`attr_name`, `attr_value`）を使うアンチパターン。拡張性を求めるあまり、RDBMSの利点を失う。

### 問題のパターン

```sql
-- ❌ 悪い例: EAVテーブル
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255)
);

CREATE TABLE ProductAttributes (
    product_id INT,
    attr_name VARCHAR(50),   -- 'price', 'weight', 'color' など
    attr_value VARCHAR(255), -- すべてVARCHAR
    PRIMARY KEY (product_id, attr_name),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- データ挿入
INSERT INTO ProductAttributes VALUES
(1, 'price', '999.99'),
(1, 'weight', '200'),
(1, 'color', 'black'),
(2, 'price', '1299.99'),
(2, 'weight', '1800');  -- colorがない
```

**問題点:**

#### 1. データ型を強制できない
```sql
-- price は DECIMAL であるべきだが、VARCHAR で格納
-- 不正な値を防げない
INSERT INTO ProductAttributes VALUES (3, 'price', 'expensive');  -- ❌
```

#### 2. 必須属性を強制できない
```sql
-- product_id=2 には 'color' がない
-- NOT NULL制約が使えない
```

#### 3. SQLが複雑化
```sql
-- 価格が1000円以上の商品を検索
SELECT p.product_id, p.product_name
FROM Products p
JOIN ProductAttributes pa ON p.product_id = pa.product_id
WHERE pa.attr_name = 'price'
  AND CAST(pa.attr_value AS DECIMAL) >= 1000;

-- 複数属性で絞り込み → JOIN地獄
SELECT p.product_id
FROM Products p
JOIN ProductAttributes pa1 ON p.product_id = pa1.product_id AND pa1.attr_name = 'price'
JOIN ProductAttributes pa2 ON p.product_id = pa2.product_id AND pa2.attr_name = 'color'
WHERE CAST(pa1.attr_value AS DECIMAL) >= 1000
  AND pa2.attr_value = 'black';
```

#### 4. パフォーマンス悪化
- 属性ごとにJOINが必要
- インデックスが効きにくい
- 行数が爆発的に増加（商品1000件 × 属性10個 = 10000行）

### 解決策

#### 方法1: 適切なテーブル設計
```sql
-- ✅ 良い例: 列として定義
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,    -- 型強制
    weight INT NOT NULL,              -- 型強制
    color VARCHAR(50) NOT NULL        -- 必須属性
);

-- シンプルなクエリ
SELECT * FROM Products
WHERE price >= 1000 AND color = 'black';
```

**メリット:**
- データ型強制（price は DECIMAL）
- 必須属性強制（NOT NULL）
- シンプルなSQL
- インデックスが効く

#### 方法2: シングルテーブル継承（サブタイプが少ない場合）
```sql
-- ✅ 良い例: シングルテーブル継承
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_type VARCHAR(20) NOT NULL,  -- 'book', 'electronics'
    product_name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    -- 書籍専用
    isbn VARCHAR(20),
    author VARCHAR(255),
    -- 電化製品専用
    warranty_months INT,
    power_consumption INT
);

-- 型ごとにCHECK制約
ALTER TABLE Products
ADD CONSTRAINT check_book_attrs
CHECK (product_type != 'book' OR (isbn IS NOT NULL AND author IS NOT NULL));
```

**注意点:**
- サブタイプの属性が少ない場合に有効
- 多数のNULL列ができる場合は次の方法を検討

#### 方法3: クラステーブル継承（サブタイプが多い場合）
```sql
-- ✅ 良い例: クラステーブル継承
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    price DECIMAL(10,2) NOT NULL
);

CREATE TABLE Books (
    product_id INT PRIMARY KEY,
    isbn VARCHAR(20) NOT NULL,
    author VARCHAR(255) NOT NULL,
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

CREATE TABLE Electronics (
    product_id INT PRIMARY KEY,
    warranty_months INT NOT NULL,
    power_consumption INT NOT NULL,
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

-- 書籍の検索
SELECT p.*, b.*
FROM Products p
JOIN Books b ON p.product_id = b.product_id
WHERE b.author = 'Martin Fowler';
```

**メリット:**
- 各サブタイプに特化した列
- 型強制、必須属性強制
- NULL列が少ない

### 検出方法

#### チェックポイント
- [ ] **`attr_name`, `attr_value` のような列があるか？**
  - 汎用的な属性テーブルの兆候

- [ ] **すべての値がVARCHARで格納されているか？**
  - データ型強制ができない

- [ ] **1つのエンティティに対して複数行が存在するか？**
  - product_id=1 に対して、price, weight, colorの3行

---

## Polymorphic Associations（ポリモーフィック関連）

### 概要
`entity_type + entity_id` で複数のテーブルを参照するアンチパターン。外部キー制約が使えず、参照整合性を保証できない。

### 問題のパターン

```sql
-- ❌ 悪い例: ポリモーフィック関連
CREATE TABLE Comments (
    comment_id INT PRIMARY KEY,
    comment_text TEXT,
    entity_type VARCHAR(20),  -- 'Bug', 'FeatureRequest'
    entity_id INT             -- Bug.id または FeatureRequest.id
);

CREATE TABLE Bugs (
    bug_id INT PRIMARY KEY,
    bug_description TEXT
);

CREATE TABLE FeatureRequests (
    request_id INT PRIMARY KEY,
    request_description TEXT
);

-- データ挿入
INSERT INTO Comments VALUES
(1, 'This is critical!', 'Bug', 123),
(2, 'I need this feature', 'FeatureRequest', 456);
```

**問題点:**

#### 1. 外部キー制約が使えない
```sql
-- 外部キーを定義できない（どのテーブルを参照するか不明）
-- → 参照整合性を保証できない

-- 存在しないIDを参照できてしまう
INSERT INTO Comments VALUES (3, 'Comment', 'Bug', 99999);  -- bug_id=99999 は存在しない
```

#### 2. JOINが複雑
```sql
-- コメントと参照先を結合したい
SELECT c.*, b.bug_description
FROM Comments c
LEFT JOIN Bugs b
  ON c.entity_type = 'Bug' AND c.entity_id = b.bug_id
LEFT JOIN FeatureRequests fr
  ON c.entity_type = 'FeatureRequest' AND c.entity_id = fr.request_id;

-- 条件分岐が複雑、パフォーマンス悪化
```

#### 3. カスケード削除が不可能
```sql
-- Bug を削除しても、関連する Comment は残る
DELETE FROM Bugs WHERE bug_id = 123;
-- Comments の entity_type='Bug', entity_id=123 は孤立
```

#### 4. 型安全性がない
```sql
-- typo を防げない
INSERT INTO Comments VALUES (4, 'Comment', 'Bugg', 123);  -- 'Bugg' は typo
```

### 解決策

#### 方法1: 共通親テーブル（推奨）
```sql
-- ✅ 良い例: 共通親テーブル
CREATE TABLE Issues (
    issue_id INT PRIMARY KEY,
    issue_type VARCHAR(20) NOT NULL  -- 'Bug', 'FeatureRequest'
);

CREATE TABLE Bugs (
    issue_id INT PRIMARY KEY,
    bug_description TEXT,
    FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);

CREATE TABLE FeatureRequests (
    issue_id INT PRIMARY KEY,
    request_description TEXT,
    FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);

CREATE TABLE Comments (
    comment_id INT PRIMARY KEY,
    comment_text TEXT,
    issue_id INT NOT NULL,
    FOREIGN KEY (issue_id) REFERENCES Issues(issue_id)
);

-- コメント挿入（外部キー制約で整合性保証）
INSERT INTO Issues VALUES (1, 'Bug');
INSERT INTO Bugs VALUES (1, 'Critical bug');
INSERT INTO Comments VALUES (1, 'This is critical!', 1);
```

**メリット:**
- 外部キー制約で参照整合性保証
- シンプルなJOIN
- カスケード削除可能

**JOIN:**
```sql
-- コメントと参照先を結合
SELECT c.*, i.issue_type, b.bug_description, fr.request_description
FROM Comments c
JOIN Issues i ON c.issue_id = i.issue_id
LEFT JOIN Bugs b ON i.issue_id = b.issue_id AND i.issue_type = 'Bug'
LEFT JOIN FeatureRequests fr ON i.issue_id = fr.issue_id AND i.issue_type = 'FeatureRequest';
```

#### 方法2: 個別の交差テーブル
```sql
-- ✅ 良い例: 個別の交差テーブル
CREATE TABLE Comments (
    comment_id INT PRIMARY KEY,
    comment_text TEXT
);

CREATE TABLE BugComments (
    comment_id INT,
    bug_id INT,
    PRIMARY KEY (comment_id, bug_id),
    FOREIGN KEY (comment_id) REFERENCES Comments(comment_id),
    FOREIGN KEY (bug_id) REFERENCES Bugs(bug_id)
);

CREATE TABLE FeatureRequestComments (
    comment_id INT,
    request_id INT,
    PRIMARY KEY (comment_id, request_id),
    FOREIGN KEY (comment_id) REFERENCES Comments(comment_id),
    FOREIGN KEY (request_id) REFERENCES FeatureRequests(request_id)
);

-- コメント挿入（外部キー制約で整合性保証）
INSERT INTO Comments VALUES (1, 'This is critical!');
INSERT INTO BugComments VALUES (1, 123);
```

**メリット:**
- 外部キー制約で参照整合性保証
- カスケード削除可能
- 1つのコメントが複数のBugに関連付け可能（多対多）

**デメリット:**
- 参照先テーブルごとに交差テーブルが必要

### 検出方法

#### チェックポイント
- [ ] **`entity_type`, `entity_id` のような列があるか？**
  - ポリモーフィック関連の兆候

- [ ] **外部キー制約がない`*_id`列があるか？**
  - 参照整合性を保証できない

- [ ] **1つの列で複数のテーブルを参照しようとしているか？**

---

## Naive Trees（ナイーブツリー）

### 概要
隣接リスト（`parent_id`）のみで木構造を表現するアンチパターン。子孫・先祖の取得が困難で、パフォーマンスが悪い。

### 問題のパターン

```sql
-- ❌ 悪い例: 隣接リスト
CREATE TABLE Categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(255),
    parent_id INT,
    FOREIGN KEY (parent_id) REFERENCES Categories(category_id)
);

-- ツリー構造
-- Electronics (1)
--   ├─ Computers (2)
--   │   ├─ Laptops (3)
--   │   └─ Desktops (4)
--   └─ Smartphones (5)

INSERT INTO Categories VALUES
(1, 'Electronics', NULL),
(2, 'Computers', 1),
(3, 'Laptops', 2),
(4, 'Desktops', 2),
(5, 'Smartphones', 1);
```

**問題点:**

#### 1. 子孫の取得が困難
```sql
-- Electronics (1) の全子孫を取得したい
-- → 再帰が必要（MySQL 8.0未満では不可能）
```

#### 2. 先祖の取得が困難
```sql
-- Laptops (3) の全先祖を取得したい（パンくずリスト）
-- → 再帰が必要
```

#### 3. 深さの取得が困難
```sql
-- Laptops (3) の深さ（ルートからの距離）を取得したい
-- → 再帰が必要
```

#### 4. サブツリーの移動が複雑
```sql
-- Computers (2) を Smartphones (5) の子に移動したい
-- → 子孫も含めて移動する必要（アプリケーション側で処理）
```

### 解決策

#### 方法1: 再帰CTE（MySQL 8.0+、PostgreSQL）
```sql
-- ✅ 良い例: 再帰CTEで子孫を取得
WITH RECURSIVE CategoryTree AS (
    -- ベースケース: Electronics (1)
    SELECT category_id, category_name, parent_id, 0 AS depth
    FROM Categories
    WHERE category_id = 1

    UNION ALL

    -- 再帰ケース: 子を取得
    SELECT c.category_id, c.category_name, c.parent_id, ct.depth + 1
    FROM Categories c
    JOIN CategoryTree ct ON c.parent_id = ct.category_id
)
SELECT * FROM CategoryTree;

-- 結果:
-- category_id | category_name | depth
-- ------------|---------------|-------
-- 1           | Electronics   | 0
-- 2           | Computers     | 1
-- 5           | Smartphones   | 1
-- 3           | Laptops       | 2
-- 4           | Desktops      | 2
```

**メリット:**
- 標準SQL（再帰CTE）
- 柔軟なクエリ

**デメリット:**
- MySQL 8.0未満では使えない
- パフォーマンスが悪い（深いツリー）

#### 方法2: 経路列挙（Path Enumeration）
```sql
-- ✅ 良い例: 経路列挙
CREATE TABLE Categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(255),
    path VARCHAR(1000)  -- '1/', '1/2/', '1/2/3/'
);

INSERT INTO Categories VALUES
(1, 'Electronics', '1/'),
(2, 'Computers', '1/2/'),
(3, 'Laptops', '1/2/3/'),
(4, 'Desktops', '1/2/4/'),
(5, 'Smartphones', '1/5/');

-- 子孫の取得（Electronics の全子孫）
SELECT * FROM Categories
WHERE path LIKE '1/%';

-- 先祖の取得（Laptops の全先祖）
SELECT * FROM Categories
WHERE '1/2/3/' LIKE CONCAT(path, '%');

-- 深さの取得
SELECT
    category_id,
    category_name,
    (LENGTH(path) - LENGTH(REPLACE(path, '/', ''))) - 1 AS depth
FROM Categories;
```

**メリット:**
- シンプルなクエリ
- MySQL 5.x でも動作

**デメリット:**
- path の長さ制限
- サブツリー移動時に子孫の path を更新

#### 方法3: 閉包テーブル（Closure Table）
```sql
-- ✅ 良い例: 閉包テーブル
CREATE TABLE Categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(255)
);

CREATE TABLE CategoryPaths (
    ancestor_id INT,
    descendant_id INT,
    depth INT,
    PRIMARY KEY (ancestor_id, descendant_id),
    FOREIGN KEY (ancestor_id) REFERENCES Categories(category_id),
    FOREIGN KEY (descendant_id) REFERENCES Categories(category_id)
);

-- データ挿入（全ての先祖-子孫関係を格納）
INSERT INTO Categories VALUES
(1, 'Electronics'), (2, 'Computers'), (3, 'Laptops'), (4, 'Desktops'), (5, 'Smartphones');

INSERT INTO CategoryPaths VALUES
-- 自分自身
(1, 1, 0), (2, 2, 0), (3, 3, 0), (4, 4, 0), (5, 5, 0),
-- Electronics の子孫
(1, 2, 1), (1, 3, 2), (1, 4, 2), (1, 5, 1),
-- Computers の子孫
(2, 3, 1), (2, 4, 1);

-- 子孫の取得（Electronics の全子孫）
SELECT c.*
FROM Categories c
JOIN CategoryPaths cp ON c.category_id = cp.descendant_id
WHERE cp.ancestor_id = 1 AND cp.depth > 0;

-- 先祖の取得（Laptops の全先祖）
SELECT c.*
FROM Categories c
JOIN CategoryPaths cp ON c.category_id = cp.ancestor_id
WHERE cp.descendant_id = 3 AND cp.depth > 0;

-- 深さの取得
SELECT c.*, cp.depth
FROM Categories c
JOIN CategoryPaths cp ON c.category_id = cp.descendant_id
WHERE cp.ancestor_id = 1;
```

**メリット:**
- 高速（JOINのみ）
- サブツリー移動が簡単

**デメリット:**
- 行数が多い（N個のノード → O(N²) 行）
- INSERT/DELETE が複雑

**ノード追加時のINSERTパターン:**
```sql
-- 新しいカテゴリ「Gaming Laptops」(id=6) を「Laptops」(id=3) の子として追加

-- 1. カテゴリ本体を挿入
INSERT INTO Categories VALUES (6, 'Gaming Laptops');

-- 2. 閉包テーブルに関係を挿入
-- 自分自身への参照
INSERT INTO CategoryPaths (ancestor_id, descendant_id, depth)
VALUES (6, 6, 0);

-- 親の先祖すべてからの参照を追加（depth + 1）
INSERT INTO CategoryPaths (ancestor_id, descendant_id, depth)
SELECT ancestor_id, 6, depth + 1
FROM CategoryPaths
WHERE descendant_id = 3;  -- 親のID

-- 結果: (1,6,3), (2,6,2), (3,6,1), (6,6,0) が追加される
```

**ノード削除時のDELETEパターン:**
```sql
-- カテゴリ「Laptops」(id=3) とその子孫を削除

-- 1. 閉包テーブルから削除（子孫への参照をすべて削除）
DELETE FROM CategoryPaths
WHERE descendant_id IN (
    SELECT descendant_id
    FROM CategoryPaths
    WHERE ancestor_id = 3
);

-- 2. カテゴリ本体を削除
DELETE FROM Categories
WHERE category_id IN (3, 6);  -- Laptops と Gaming Laptops
```

**サブツリー移動のパターン:**
```sql
-- 「Computers」(id=2) を「Smartphones」(id=5) の子に移動

-- 1. 古い先祖との関係を削除（自分自身以外）
DELETE FROM CategoryPaths
WHERE descendant_id IN (
    SELECT descendant_id FROM CategoryPaths WHERE ancestor_id = 2
)
AND ancestor_id IN (
    SELECT ancestor_id FROM CategoryPaths WHERE descendant_id = 2 AND ancestor_id != descendant_id
);

-- 2. 新しい先祖との関係を追加
INSERT INTO CategoryPaths (ancestor_id, descendant_id, depth)
SELECT supertree.ancestor_id, subtree.descendant_id,
       supertree.depth + subtree.depth + 1
FROM CategoryPaths AS supertree
CROSS JOIN CategoryPaths AS subtree
WHERE supertree.descendant_id = 5  -- 新しい親
  AND subtree.ancestor_id = 2;     -- 移動するノード
```

### 検出方法

#### チェックポイント
- [ ] **`parent_id` のみで木構造を表現しているか？**
  - 隣接リストの兆候

- [ ] **再帰クエリを使っているか？**
  - パフォーマンス問題の可能性

- [ ] **子孫・先祖の取得が頻繁か？**
  - 経路列挙または閉包テーブルを検討

---

## Multicolumn Attributes（複数列属性）

### 概要
`tag1`, `tag2`, `tag3`... のように同じ意味の列を複数定義するアンチパターン。検索が複雑で、列数の上限がある。

### 問題のパターン

```sql
-- ❌ 悪い例: 複数列属性
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255),
    tag1 VARCHAR(50),
    tag2 VARCHAR(50),
    tag3 VARCHAR(50)
);

INSERT INTO Products VALUES
(1, 'iPhone 15', 'electronics', 'smartphone', '5g'),
(2, 'MacBook Pro', 'electronics', 'laptop', NULL);  -- tag3 は NULL
```

**問題点:**

#### 1. 検索が複雑
```sql
-- 'smartphone' タグの商品を検索
SELECT * FROM Products
WHERE tag1 = 'smartphone'
   OR tag2 = 'smartphone'
   OR tag3 = 'smartphone';

-- インデックスが効きにくい
```

#### 2. 列数の上限
```sql
-- 4つ目のタグを追加したい → ALTER TABLE が必要
ALTER TABLE Products ADD COLUMN tag4 VARCHAR(50);

-- 既存のクエリも修正が必要
```

#### 3. NULLが多い
```sql
-- product_id=2 は tag3 が NULL
-- ストレージの無駄
```

#### 4. 集計が困難
```sql
-- タグごとの商品数を集計したい
SELECT 'tag1' AS tag_position, tag1 AS tag, COUNT(*) AS cnt
FROM Products WHERE tag1 IS NOT NULL GROUP BY tag1
UNION ALL
SELECT 'tag2', tag2, COUNT(*)
FROM Products WHERE tag2 IS NOT NULL GROUP BY tag2
UNION ALL
SELECT 'tag3', tag3, COUNT(*)
FROM Products WHERE tag3 IS NOT NULL GROUP BY tag3;

-- 複雑で保守性が低い
```

### 解決策: 従属テーブルに分離

```sql
-- ✅ 良い例: 従属テーブル
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255)
);

CREATE TABLE ProductTags (
    product_id INT,
    tag_name VARCHAR(50),
    PRIMARY KEY (product_id, tag_name),
    FOREIGN KEY (product_id) REFERENCES Products(product_id)
);

INSERT INTO Products VALUES
(1, 'iPhone 15'),
(2, 'MacBook Pro');

INSERT INTO ProductTags VALUES
(1, 'electronics'), (1, 'smartphone'), (1, '5g'),
(2, 'electronics'), (2, 'laptop');

-- 検索がシンプル
SELECT p.*
FROM Products p
JOIN ProductTags pt ON p.product_id = pt.product_id
WHERE pt.tag_name = 'smartphone';

-- 集計がシンプル
SELECT tag_name, COUNT(*) AS product_count
FROM ProductTags
GROUP BY tag_name;
```

**メリット:**
- シンプルなSQL
- 列数の制限なし
- NULLなし
- インデックスが効く

### 検出方法

#### チェックポイント
- [ ] **同じ意味の列が複数あるか？**
  - `tag1`, `tag2`, `tag3`
  - `phone1`, `phone2`, `phone3`
  - `email_primary`, `email_secondary`

- [ ] **列数の上限があるか？**
  - 固定数の列で表現

- [ ] **OR条件が多いクエリがあるか？**
  - `WHERE col1 = X OR col2 = X OR col3 = X`

---

## Metadata Tribbles（メタデータ大増殖）

### 概要
`Bugs_2023`, `Bugs_2024`... のように年度ごとにテーブルを分割するアンチパターン。クエリがUNIONだらけになり、保守性が低い。

### 問題のパターン

```sql
-- ❌ 悪い例: 年度ごとにテーブル分割
CREATE TABLE Bugs_2023 (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    created_at DATE
);

CREATE TABLE Bugs_2024 (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    created_at DATE
);

CREATE TABLE Bugs_2025 (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    created_at DATE
);
```

**問題点:**

#### 1. クエリがUNIONだらけ
```sql
-- 全期間のバグを検索
SELECT * FROM Bugs_2023
UNION ALL
SELECT * FROM Bugs_2024
UNION ALL
SELECT * FROM Bugs_2025;

-- 新しい年度が増えるたびにクエリ修正
```

#### 2. 集計が複雑
```sql
-- 年度ごとのバグ数
SELECT '2023' AS year, COUNT(*) FROM Bugs_2023
UNION ALL
SELECT '2024', COUNT(*) FROM Bugs_2024
UNION ALL
SELECT '2025', COUNT(*) FROM Bugs_2025;
```

#### 3. 外部キー制約が困難
```sql
-- Comments テーブルから Bugs を参照したい
CREATE TABLE Comments (
    comment_id INT PRIMARY KEY,
    bug_id INT,
    -- どのテーブルを参照するか不明 → 外部キー制約不可
);
```

#### 4. 年度をまたぐ検索が困難
```sql
-- 2023年12月〜2024年1月のバグを検索
SELECT * FROM Bugs_2023 WHERE created_at >= '2023-12-01'
UNION ALL
SELECT * FROM Bugs_2024 WHERE created_at < '2024-02-01';

-- 複雑
```

#### 5. メタデータ管理が煩雑
```sql
-- 新年度になるたびに新しいテーブルを作成
CREATE TABLE Bugs_2026 (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    created_at DATE
);

-- アプリケーション側でテーブル名を動的に切り替え
table_name = f"Bugs_{current_year}"
```

### 解決策: 1テーブルに統合 + パーティショニング

```sql
-- ✅ 良い例: 1テーブルに統合
CREATE TABLE Bugs (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    created_at DATE
);

-- すべてのデータを統合
INSERT INTO Bugs
SELECT * FROM Bugs_2023
UNION ALL
SELECT * FROM Bugs_2024
UNION ALL
SELECT * FROM Bugs_2025;

-- シンプルなクエリ
SELECT * FROM Bugs
WHERE created_at >= '2023-12-01' AND created_at < '2024-02-01';

-- 集計もシンプル
SELECT YEAR(created_at) AS year, COUNT(*) AS bug_count
FROM Bugs
GROUP BY YEAR(created_at);
```

**パーティショニング（大量データの場合）:**
```sql
-- MySQL 5.1+: パーティショニングで物理的に分割
CREATE TABLE Bugs (
    bug_id INT PRIMARY KEY,
    bug_description TEXT,
    created_at DATE
)
PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2023 VALUES LESS THAN (2024),
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026)
);

-- 論理的には1テーブル（クエリはシンプル）
SELECT * FROM Bugs WHERE created_at >= '2024-01-01';

-- 物理的にはパーティションで分割（パフォーマンス向上）
```

**メリット:**
- シンプルなSQL
- 外部キー制約可能
- メタデータ管理が容易
- パーティショニングでパフォーマンス維持

### 検出方法

#### チェックポイント
- [ ] **テーブル名に年度・月が含まれるか？**
  - `Bugs_2023`, `Sales_202401`

- [ ] **同じ構造のテーブルが複数あるか？**
  - 年度ごと、月ごとに分割

- [ ] **UNIONで複数テーブルを結合しているか？**
  - クエリが複雑

---

## まとめ

### 論理設計アンチパターン早見表

| アンチパターン | 問題 | 解決策 |
|---|---|---|
| **Jaywalking** | カンマ区切りリスト | 交差テーブル |
| **EAV** | 汎用属性テーブル | 適切なテーブル設計、継承パターン |
| **Polymorphic Associations** | entity_type + entity_id | 共通親テーブル、個別交差テーブル |
| **Naive Trees** | parent_id のみ | 再帰CTE、経路列挙、閉包テーブル |
| **Multicolumn Attributes** | tag1, tag2, tag3 | 従属テーブル |
| **Metadata Tribbles** | テーブル大増殖 | 1テーブル統合 + パーティショニング |

### 共通の教訓

1. **第1正規形を守る**: カンマ区切りは悪
2. **外部キー制約を使う**: 参照整合性を保証
3. **メタデータとデータを分離**: ENUMより参照テーブル
4. **柔軟性と型安全性のバランス**: EAVは避ける
5. **RDBMSの機能を活用**: 再帰CTE、パーティショニング

---

## 参考資料

- O'Reilly「SQLアンチパターン」(oreilly-978-4-8144-0074-4e)
