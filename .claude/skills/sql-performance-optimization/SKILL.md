# SQL Performance Optimization Skill

このスキルはSQL性能最適化に関する問題を解決します。

---

## 対応できること

- SQLクエリのレビュー
- 遅いクエリの原因診断
- 実行計画の読み方
- インデックス設計
- クエリ比較

---

## ディレクトリ構成

```
.claude/skills/sql-performance-optimization/
├── knowledge/     - 性能問題のパターンと解決策（詳細ドキュメント）
├── tasks/         - タスク別ガイド（レビュー手順、診断手順等）
└── examples/      - 改善前後の具体例
```

---

## Knowledge Files（核心知識）

| ファイル | 内容 |
|---------|------|
| [anti-patterns.md](knowledge/anti-patterns.md) | 冗長性症候群、N+1問題、三角結合、サブクエリ・パラノイア、シーケンス乱用、スーパーソルジャー病 |
| [query-antipatterns.md](knowledge/query-antipatterns.md) | スパゲッティクエリ、曖昧なグループ（GROUP BY違反）、暗黙の列（SELECT *）、LIKE検索、ランダムセレクション |
| [window-functions.md](knowledge/window-functions.md) | GROUP BY vs PARTITION BY、LAG/LEAD/ROW_NUMBER、サブクエリ→ウィンドウ関数置換、UPDATE活用 |
| [index-strategies.md](knowledge/index-strategies.md) | インデックスが効く条件、効かない5パターン、複合インデックス順序、カバリングインデックス |
| [join-algorithms.md](knowledge/join-algorithms.md) | Nested Loops/Hash/Sort Merge、駆動表・内部表の選択、実行計画変動リスク |
| [subquery-problems.md](knowledge/subquery-problems.md) | サブクエリの4つの問題（一時領域/インデックス無効/結合発生/I/O増加）、ウィンドウ関数解決 |
| [temp-fall.md](knowledge/temp-fall.md) | TEMP落ちとは、発生する処理、検出方法、対策（メモリ/絞り込み/インデックス） |

---

## Tasks Files（作業ガイド）

| ファイル | 内容 |
|---------|------|
| [review-query.md](tasks/review-query.md) | SQLクエリレビューチェックリスト（11項目：CASE式、集約、ループ、結合、サブクエリ、順序、更新、TEMP落ち、複雑度、データモデル、インデックス） |
| [diagnose-slow-query.md](tasks/diagnose-slow-query.md) | 遅いクエリの診断手順（症状確認、実行計画取得、ボトルネック特定、原因分類、改善策提示） |
| [read-execution-plan.md](tasks/read-execution-plan.md) | 実行計画の読み方（type/Extra/FORMAT=TREE解説、危険サイン判別、改善指針） |
| [design-index.md](tasks/design-index.md) | インデックス設計ガイド（手順、複合インデックス順序、カーディナリティ確認） |
| [compare-queries.md](tasks/compare-queries.md) | クエリ比較手順（実行計画・行数・インデックス・ソート・可読性の5観点） |

---

## Examples Files（実例集）

| ファイル | 内容 |
|---------|------|
| [before-after.md](examples/before-after.md) | 改善前後の比較例（UNION→CASE式等） |
| [common-patterns.md](examples/common-patterns.md) | よくあるパターン集（CASE式+集約、ウィンドウ関数、更新系パターン等） |

---

## クイックガイド：こんな時はこのファイル

| ユースケース | 参照ファイル |
|------------|-------------|
| **クエリが遅い原因を知りたい** | [anti-patterns.md](knowledge/anti-patterns.md), [review-query.md](tasks/review-query.md) |
| **クエリが複雑すぎる** | [query-antipatterns.md](knowledge/query-antipatterns.md) |
| **GROUP BYでエラーが出る** | [query-antipatterns.md](knowledge/query-antipatterns.md) |
| **インデックスを設計したい** | [index-strategies.md](knowledge/index-strategies.md) |
| **結合が遅い** | [join-algorithms.md](knowledge/join-algorithms.md) |
| **サブクエリを最適化したい** | [subquery-problems.md](knowledge/subquery-problems.md), [window-functions.md](knowledge/window-functions.md) |
| **TEMP落ちが発生している** | [temp-fall.md](knowledge/temp-fall.md) |
| **ウィンドウ関数の使い方を知りたい** | [window-functions.md](knowledge/window-functions.md) |
| **改善例が見たい** | [before-after.md](examples/before-after.md), [common-patterns.md](examples/common-patterns.md) |
| **SQLをレビューしたい** | [review-query.md](tasks/review-query.md) |

---

## 使い方（Claudeへの指示例）

### 1. SQLクエリレビュー
```
このクエリをレビューして

SELECT * FROM ...
```

### 2. 遅いクエリの診断
```
このクエリが遅い原因を診断して

EXPLAIN結果:
...
```

### 3. サブクエリ最適化
```
このサブクエリをウィンドウ関数に置き換えて

SELECT R1.* FROM Receipts R1
INNER JOIN (
    SELECT cust_id, MIN(seq) AS min_seq
    FROM Receipts
    GROUP BY cust_id
) R2 ...
```

### 4. インデックス設計
```
このテーブルにインデックスを設計して

CREATE TABLE Orders (
    order_id INT,
    customer_id INT,
    order_date DATE,
    ...
);

よく実行されるクエリ:
SELECT * FROM Orders WHERE customer_id = ? AND order_date >= ?;
```

### 5. 実行計画の読み解き
```
この実行計画を読み解いて

-> Inner hash join (cost=500 rows=100)
    -> Table scan on R1 ...
```

---

## カスタムコマンドでの呼び出し

```
/sql-review SELECT * FROM ...
```

または

```
/sql-review path/to/query.sql
```

詳細は `.claude/commands/sql-review.md` を参照。

---

## 核心メッセージ（書籍ベース）

このスキルは以下の原則に基づいています：

1. **WHERE句ではなくSELECT句で分岐させる**（CASE式）
2. **1にI/O、2にI/O、3、4がなくて5にI/O**（サブクエリ削減）
3. **ぐるぐる系ではなくガツン系**（N+1問題解消）
4. **1にNested Loops、2にHash**（結合アルゴリズム）
5. **困難は分割するな**（サブクエリ→ウィンドウ関数）
6. **SQLを頑張る前に、データモデルを見直せ**（スーパーソルジャー病）

---

## 関連スキル

クエリ性能の問題は、DB設計に起因することがあります。以下のケースでは `database-design-patterns` スキルも参照してください。

| 性能問題 | 設計上の原因 | 参照先 |
|---------|-------------|--------|
| LIKE '%x%' が遅い | Jaywalking（カンマ区切り格納） | database-design-patterns/knowledge/logical-design-antipatterns.md |
| JOINが多すぎる | EAV（汎用属性テーブル） | database-design-patterns/knowledge/logical-design-antipatterns.md |
| 再帰クエリが遅い | Naive Trees（parent_idのみ） | database-design-patterns/knowledge/logical-design-antipatterns.md |
| UNIONだらけ | Metadata Tribbles（テーブル分割） | database-design-patterns/knowledge/logical-design-antipatterns.md |

DB設計のレビューは `/db-review` コマンドを使用してください。

---

## 構成情報

- **書籍ベース:** `sql-performance-optimization.pdf`
- **実装済み章:** 第3章〜第9章（CASE式、集約、ループ、結合、サブクエリ、順序、更新・モデル）
- **第10章:** インデックス戦略（最新追加）
