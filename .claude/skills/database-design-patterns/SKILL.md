# Database Design Patterns

このスキルはデータベース設計に関するアンチパターンを検出し、改善案を提示します。

---

## 対応できること

- テーブル設計のレビュー
- 論理設計アンチパターンの検出
- 物理設計アンチパターンの検出
- 正規化の確認
- 外部キー制約の妥当性確認

---

## ディレクトリ構成

```
.claude/skills/database-design-patterns/
├── SKILL.md
└── knowledge/
    ├── logical-design-antipatterns.md   - 論理設計のアンチパターン
    └── physical-design-antipatterns.md  - 物理設計のアンチパターン
```

---

## Knowledge Files

| ファイル | 内容 |
|---------|------|
| [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md) | Jaywalking、EAV、ポリモーフィック関連、ナイーブツリー、複数列属性、メタデータ大増殖 |
| [physical-design-antipatterns.md](knowledge/physical-design-antipatterns.md) | ENUM乱用、FLOAT金額、ファイルパスのみ格納 |

---

## クイックガイド：こんな時はこのファイル

| ユースケース | 参照ファイル |
|------------|-------------|
| **カンマ区切りのデータが列に入っている** | [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md#jaywalkingジェイウォーク) |
| **汎用的な属性テーブルを作ろうとしている** | [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md#eavエンティティアトリビュートバリュー) |
| **複数のテーブルを1つの外部キーで参照したい** | [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md#polymorphic-associationsポリモーフィック関連) |
| **木構造（ツリー）をDBに格納したい** | [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md#naive-treesナイーブツリー) |
| **tag1, tag2, tag3... のような列がある** | [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md#multicolumn-attributes複数列属性) |
| **年度ごとにテーブルを分けている** | [logical-design-antipatterns.md](knowledge/logical-design-antipatterns.md#metadata-tribblesメタデータ大増殖) |
| **ENUMやCHECK制約で値を制限している** | [physical-design-antipatterns.md](knowledge/physical-design-antipatterns.md#31-flavorsサーティワンフレーバー) |
| **金額をFLOAT/DOUBLEで格納している** | [physical-design-antipatterns.md](knowledge/physical-design-antipatterns.md#rounding-errors丸め誤差) |
| **ファイルパスのみDBに格納している** | [physical-design-antipatterns.md](knowledge/physical-design-antipatterns.md#phantom-filesファントムファイル) |

---

## 使い方（Claudeへの指示例）

### 1. テーブル設計レビュー
```
このテーブル設計をレビューして

CREATE TABLE Products (
    id INT PRIMARY KEY,
    name VARCHAR(255),
    tags VARCHAR(1000)  -- カンマ区切り
);
```

### 2. 正規化の確認
```
このテーブルは正規化されているか確認して

CREATE TABLE Orders (
    order_id INT PRIMARY KEY,
    customer_name VARCHAR(255),
    customer_email VARCHAR(255),
    product_name VARCHAR(255),
    price DECIMAL(10,2)
);
```

### 3. 外部キー制約の確認
```
このER図の外部キー制約は適切か確認して

[テーブル定義またはER図]
```

---

## カスタムコマンドでの呼び出し

```
/db-review CREATE TABLE ...
```

または

```
/db-review path/to/schema.sql
```

---

## 核心メッセージ

このスキルは以下の原則に基づいています：

1. **カンマ区切りは悪**: リレーショナルデータベースを使うなら、正規化する
2. **汎用テーブルは避ける**: 型安全性とSQL簡潔性を失う
3. **外部キー制約は必須**: 参照整合性を保証する
4. **ENUMより参照テーブル**: メタデータとデータを分離
5. **金額はDECIMAL**: 浮動小数点は誤差が蓄積する
6. **木構造には専用手法**: 再帰CTE、閉包テーブル、経路列挙

---

## 参考資料

- O'Reilly「SQLアンチパターン」(oreilly-978-4-8144-0074-4e)
