---
description: SQLクエリのパフォーマンスレビュー
---

指定されたSQLクエリまたはファイルをレビューしてください。

## 参照するスキル

まず `.claude/skills/sql-performance-optimization/SKILL.md` を読み込む。
次に、入力されたSQLに応じて以下のファイルを参照：

- アンチパターン全般 → knowledge/anti-patterns.md
- インデックス関連 → knowledge/index-strategies.md
- サブクエリ関連 → knowledge/subquery-problems.md
- 結合アルゴリズム → knowledge/join-algorithms.md
- ウィンドウ関数 → knowledge/window-functions.md
- TEMP落ち → knowledge/temp-fall.md

## レビュー観点

1. アンチパターンの検出（N+1、サブクエリ・パラノイア、冗長性症候群など）
2. インデックスの効きやすさ（5つの効かないパターン）
3. 実行計画の予測
4. 改善案の提示（before/after形式）

## 入力

$ARGUMENTS

## 出力形式

- 問題点: 検出されたアンチパターンや性能問題
- 重要度: 高/中/低
- 改善案: 具体的なSQLの書き換え例
- 参考: 該当するknowledgeファイルへの参照

## 出力例

### 入力
```sql
SELECT *
FROM orders o
WHERE o.customer_id IN (
    SELECT customer_id
    FROM customers
    WHERE region = 'Tokyo'
);
```

### 出力

**検出された問題:**

| 問題 | 重要度 |
|------|--------|
| サブクエリをJOINに書き換え可能 | 中 |
| SELECT * の使用 | 低 |

**改善案:**
```sql
SELECT o.order_id, o.order_date, o.amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE c.region = 'Tokyo';
```

**理由:**
- JOINの方がオプティマイザが最適化しやすい
- SELECT * は不要な列を取得する（I/O増加）

**参考:** knowledge/subquery-problems.md
