---
description: SQLクエリのパフォーマンスレビュー
---

指定されたSQLクエリまたはファイルをレビューしてください。

## 参照するスキル
`.claude/skills/sql-performance-optimization/SKILL.md` を読み、関連するknowledge/tasks/examplesファイルを参照してレビューを行う。

## レビュー観点
1. アンチパターンの検出（N+1、サブクエリ・パラノイア、冗長性症候群など）
2. インデックスの効きやすさ
3. 実行計画の予測
4. 改善案の提示（before/after形式）

## 入力
$ARGUMENTS

## 出力形式
- 問題点: 検出されたアンチパターンや性能問題
- 重要度: 高/中/低
- 改善案: 具体的なSQLの書き換え例
- 参考: 該当するknowledgeファイルへの参照
