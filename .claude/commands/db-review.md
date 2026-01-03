---
description: データベース設計のレビュー
---

指定されたテーブル定義またはER図をレビューしてください。

## 参照するスキル

まず `.claude/skills/database-design-patterns/SKILL.md` を読み込む。
次に、入力された定義に応じて以下のファイルを参照：

- カンマ区切り、多対多関連 → knowledge/logical-design-antipatterns.md#jaywalkingジェイウォーク
- 汎用属性テーブル → knowledge/logical-design-antipatterns.md#eavエンティティアトリビュートバリュー
- entity_type + entity_id → knowledge/logical-design-antipatterns.md#polymorphic-associationsポリモーフィック関連
- 木構造、parent_id → knowledge/logical-design-antipatterns.md#naive-treesナイーブツリー
- tag1, tag2, tag3 → knowledge/logical-design-antipatterns.md#multicolumn-attributes複数列属性
- 年度別テーブル → knowledge/logical-design-antipatterns.md#metadata-tribblesメタデータ大増殖
- ENUM、CHECK制約 → knowledge/physical-design-antipatterns.md#31-flavorsサーティワンフレーバー
- FLOAT金額 → knowledge/physical-design-antipatterns.md#rounding-errors丸め誤差
- ファイルパス格納 → knowledge/physical-design-antipatterns.md#phantom-filesファントムファイル

## 検出手順

1. 入力されたDDLをパース
2. 各knowledgeファイルの「検出方法」セクションのチェックリストを順に確認
3. 該当するアンチパターンを報告

## レビュー観点

1. 論理設計アンチパターンの検出（Jaywalking、EAV、ポリモーフィック関連など）
2. 物理設計アンチパターンの検出（ENUM乱用、FLOAT金額など）
3. 正規化の状態
4. 外部キー制約の有無
5. 改善案の提示

## 入力

$ARGUMENTS

## 出力形式

- 検出されたアンチパターン: 名前と該当箇所
- 重要度: 高/中/低
- 改善案: 具体的なテーブル定義の書き換え例
- トレードオフ: 改善による影響（あれば）
- 参考: 該当するknowledgeファイルへの参照

## 出力例

### 入力
```sql
CREATE TABLE Products (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    tags VARCHAR(1000)
);
```

### 出力

**検出されたアンチパターン:**

| アンチパターン | 該当箇所 | 重要度 |
|--------------|---------|--------|
| Jaywalking（ジェイウォーク） | tags列 | 高 |

**問題点:**
- `tags` 列にカンマ区切りでデータを格納しようとしている
- 検索時にインデックスが効かない
- JOINが困難

**改善案:**
```sql
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    name VARCHAR(255)
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
```

**参考:** knowledge/logical-design-antipatterns.md#jaywalkingジェイウォーク
