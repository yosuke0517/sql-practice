# 結合アルゴリズム

> 「結合はSQLの性能問題の火薬庫。アルゴリズムを理解せよ」

---

## 概要

SQLの結合（JOIN）は、**機能面**（どんな結果を返すか）と**実装面**（どうやって処理するか）の2つの視点で理解する必要がある。

- **機能面**: クロス結合、内部結合、外部結合、自己結合
- **実装面**: Nested Loops、Hash、Sort Merge（**本ファイルの主題**）

性能問題の大半は**実装面のアルゴリズム選択**に起因する。

---

## 結合の種類（機能面）

| 種類 | 説明 | 実務での使用頻度 |
|------|------|-----------------|
| **クロス結合** | 全行 × 全行（直積） | ほぼ使わない |
| **内部結合** | 両方に存在する行のみ返す | ✅ 最頻出 |
| **外部結合** | 片方にしかない行も返す（LEFT/RIGHT/FULL） | ✅ よく使う |
| **自己結合** | 同じテーブル同士を結合 | △ 特定用途 |

---

## 結合アルゴリズム（実装面）

データベースは内部で以下の3つのアルゴリズムから最適なものを選択する。

| アルゴリズム | 動作 | 適用ケース |
|-------------|------|-----------|
| **Nested Loops** | 二重ループ | 小-大の結合、OLTP |
| **Hash** | ハッシュテーブル作成 | 大-大の結合、バッチ |
| **Sort Merge** | 両方ソートしてマージ | ソート済みデータ、不等号結合 |

---

## Nested Loops（ネステッド・ループ）

### 動作イメージ

```
外側ループ（駆動表 Driving Table）
  └─ 内側ループ（内部表 Inner Table）
       └─ 結合条件に合致？ → 結果に追加
```

**疑似コード:**
```java
for (Row outer : drivingTable) {  // 駆動表をスキャン
    for (Row inner : innerTable) { // 内部表をスキャン
        if (outer.id == inner.id) { // 結合条件
            result.add(merge(outer, inner));
        }
    }
}
```

### 高速化の鉄則

✅ **駆動表は小さく**
✅ **内部表の結合キーにインデックス**

#### なぜインデックスが重要か？

| 状況 | アクセス回数 |
|------|-------------|
| インデックスなし | `R(A) × R(B)` 回（全件スキャン） |
| インデックスあり | `R(A) × 2` 回（理想的には対数時間） |

**例:** 駆動表100行、内部表10,000行の場合
- インデックスなし: 100 × 10,000 = **1,000,000回アクセス**
- インデックスあり: 100 × 2 = **200回アクセス**（約5000倍高速）

### 適用ケース

✅ **小さなテーブル × 大きなテーブル**
✅ **OLTP（短時間トランザクション）**
✅ **内部表にインデックスがある**
❌ 大きなテーブル同士の結合

---

## Hash（ハッシュ結合）

### 動作イメージ

```
1. Build フェーズ:  小さいテーブルでハッシュテーブル作成
2. Probe フェーズ:  大きいテーブルをスキャン → ハッシュ検索（O(1)）
```

**疑似コード:**
```java
// Build フェーズ
HashMap<Integer, Row> hashTable = new HashMap<>();
for (Row row : buildTable) {  // 小さいテーブル
    hashTable.put(row.id, row);
}

// Probe フェーズ
for (Row row : probeTable) {  // 大きいテーブル
    Row matched = hashTable.get(row.id);  // O(1) 検索
    if (matched != null) {
        result.add(merge(row, matched));
    }
}
```

### 特徴

✅ **等値結合（`=`）のみ対応**
✅ **大きなテーブル同士の結合に有効**
❌ **メモリを多く消費** → **TEMP落ちリスク**
❌ 不等号（`<`, `>`）には使えない

### 適用ケース

✅ **大きなテーブル × 大きなテーブル**
✅ **バッチ処理**
✅ **インデックスがない場合の次善策**
❌ OLTP（メモリ消費が大きい）

---

## Sort Merge（ソート・マージ結合）

### 動作イメージ

```
1. Sort フェーズ:  両テーブルを結合キーでソート
2. Merge フェーズ: 順番にマージ（ソート済み前提で効率的）
```

**疑似コード:**
```java
// Sort フェーズ
List<Row> sortedA = sort(tableA, "id");
List<Row> sortedB = sort(tableB, "id");

// Merge フェーズ
int i = 0, j = 0;
while (i < sortedA.size() && j < sortedB.size()) {
    if (sortedA[i].id == sortedB[j].id) {
        result.add(merge(sortedA[i], sortedB[j]));
        i++; j++;
    } else if (sortedA[i].id < sortedB[j].id) {
        i++;
    } else {
        j++;
    }
}
```

### 特徴

✅ **不等号（`<`, `>`）も使える**
✅ **既にソート済みならスキップ可能**（例: インデックススキャン）
❌ **メモリ消費大**（ソート処理）
❌ 等値結合ではHashより遅い

### 適用ケース

✅ **不等号を使った結合**
✅ **既にソート済みのデータ**（インデックス順スキャン）
❌ 通常の等値結合（Hashの方が高速）

---

## 3つのアルゴリズム比較

| 観点 | Nested Loops | Hash | Sort Merge |
|------|--------------|------|------------|
| **メモリ消費** | 小 | 大 | 大 |
| **適用条件** | どれでも | 等値のみ | 否定以外 |
| **小-大テーブル** | ✅ 最適 | △ | △ |
| **大-大テーブル** | △ | ✅ 最適 | ○ |
| **OLTP向き** | ✅ | ❌ | ❌ |
| **インデックス依存** | 高（内部表） | 低 | 低 |
| **TEMP落ちリスク** | 低 | 高 | 高 |

### 優先順位

```
1位: Nested Loops（小-大 + インデックス）
2位: Hash（大-大の等値結合）
3位: Sort Merge（不等号結合、ソート済みデータ）
```

---

## 結合が遅い時のチェックリスト

### 1. 駆動表は小さいか？

```sql
-- ❌ 悪い例: 大きいテーブルが駆動表
SELECT *
FROM LargeTable A  -- 100万行
JOIN SmallTable B  -- 100行
  ON A.id = B.id;

-- ✅ 良い例: 小さいテーブルが駆動表（明示的に指定）
SELECT *
FROM SmallTable B  -- 100行
JOIN LargeTable A  -- 100万行
  ON B.id = A.id;
```

**判断基準:**
- FROM句の最初のテーブルが駆動表になることが多い（DBMS依存）
- `EXPLAIN` で実行計画を確認

### 2. 内部表の結合キーにインデックスあるか？

```sql
-- ❌ 悪い例: インデックスなし → Table scan
EXPLAIN
SELECT *
FROM SmallTable A
JOIN LargeTable B  -- B.id にインデックスなし
  ON A.id = B.id;

-- ✅ 良い例: インデックスあり → Index lookup
CREATE INDEX idx_large_id ON LargeTable(id);
```

**EXPLAIN での確認:**
- `Table scan on B` → ❌ インデックス未使用
- `Index lookup on B using idx_large_id` → ✅ インデックス使用

### 3. 内部表のヒット件数が多すぎないか？

```sql
-- ❌ 悪い例: 1行の駆動表 → 100万行の内部表
SELECT *
FROM Orders O        -- 1行
JOIN OrderDetails D  -- 100万行（1注文に100万明細）
  ON O.order_id = D.order_id;
```

**対策:**
- WHERE句で内部表を絞り込む
- 結合前にサブクエリで集約

### 4. 意図せぬクロス結合が発生してないか？

```sql
-- ❌ 悪い例: 結合条件忘れ → クロス結合
SELECT *
FROM TableA A, TableB B, TableC C
WHERE A.id = B.id;
-- C が孤立 → A × B × C の直積

-- ✅ 良い例: 全テーブルに結合条件
SELECT *
FROM TableA A
JOIN TableB B ON A.id = B.id
JOIN TableC C ON B.id = C.id;
```

**検出方法:**
- `EXPLAIN` で `rows` が異常に大きい
- 実行時間が予想外に長い

---

## 実行計画変動リスク

### 問題

データ量が変化すると、オプティマイザが**別のアルゴリズムを選択** → 性能が激変

```
【初期】テーブルA: 100行 → Nested Loops（高速）
【1年後】テーブルA: 100万行 → Hash（TEMP落ち）
```

### 対策

#### 1. ヒント句で固定（慎重に使用）

```sql
-- MySQL
SELECT /*+ NO_HASH_JOIN(A B) */ *
FROM TableA A
JOIN TableB B ON A.id = B.id;
```

**リスク:**
- データ量が変わると逆に遅くなる可能性
- DBMS依存の構文

#### 2. そもそも結合を避ける

```sql
-- ❌ 結合
SELECT A.name, MAX(B.score)
FROM Students A
JOIN Scores B ON A.id = B.student_id
GROUP BY A.name;

-- ✅ ウィンドウ関数で代替
SELECT DISTINCT
    name,
    MAX(score) OVER (PARTITION BY student_id) AS max_score
FROM StudentsWithScores;
```

---

## 判断フロー

```
結合が必要？
├─ YES → 次へ
└─ NO  → ウィンドウ関数/サブクエリで代替を検討

駆動表は小さいか？
├─ YES → 次へ
└─ NO  → FROM句の順序変更/WHERE句で絞り込み

内部表の結合キーにインデックスあるか？
├─ YES → Nested Loops で高速化
└─ NO  → インデックス追加 or Hash結合を許容

内部表のヒット件数は適切か？
├─ YES → OK
└─ NO  → WHERE句で絞り込み/サブクエリで集約

意図せぬクロス結合はないか？
├─ NO  → OK
└─ YES → 結合条件を追加
```

---

## まとめ

### 基本方針

**1にNested Loops、2にHash**

### Nested Loops を効かせるには

✅ 小さな駆動表
✅ 内部表の結合キーにインデックス
✅ 内部表のヒット件数を抑える

### 結合の問題点

❌ 実行計画が変動しやすい
❌ TEMP落ちリスク
❌ データ量増加で性能劣化

### 究極の対策

**結合を使わない（ウィンドウ関数で代替）**

---

## 参照

- [アンチパターン](./anti-patterns.md#意図せぬクロス結合三角結合) - 三角結合
- [TEMP落ち](./temp-fall.md) - メモリ不足の検出と対策
- [ウィンドウ関数](./window-functions.md) - 結合の代替手段
- [クエリレビュータスク](../tasks/review-query.md#4-join) - 結合のチェックリスト
