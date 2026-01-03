# インデックス戦略

## 概要

インデックスは魔法の杖じゃない。効く条件を理解して使う。

---

## インデックスが効く条件

### カーディナリティ
```
値のばらつき度合い

高い（効く）:
  - ユニークキー
  - ユーザーID、注文番号など

低い（効かない）:
  - フラグ（0/1）
  - 性別（M/F）
  - ステータス（数種類）
```

### 選択率
```
その条件で何%に絞り込めるか

目安: 5〜10% 以下なら効く

例:
  1億件中1件 → 効く
  1億件中5000万件 → フルスキャンの方が速い
```

---

## インデックスが効かない5パターン

### ❌ 1. LIKE中間・後方一致
```sql
-- 効かない
WHERE name LIKE '%田中%'
WHERE name LIKE '%田中'

-- 効く（前方一致のみ）
WHERE name LIKE '田中%'
```

### ❌ 2. 列を加工（計算・関数）
```sql
-- 効かない
WHERE col * 1.1 > 100
WHERE YEAR(sale_date) = 2024

-- 効く（右辺で計算）
WHERE col > 100 / 1.1
WHERE sale_date >= '2024-01-01' AND sale_date < '2025-01-01'
```

### ❌ 3. 否定形
```sql
-- 効かない
WHERE status <> 'deleted'
WHERE id NOT IN (1, 2, 3)
```

### ❌ 4. IS NULL
```sql
-- 効かない（実装による）
WHERE deleted_at IS NULL
```

### ❌ 5. 選択率が高い
```sql
-- 効かない（ほとんどヒットする）
WHERE is_active = 1  -- 90%がactiveなら無駄
```

---

## 複合インデックスの順序
```sql
CREATE INDEX idx ON orders(customer_id, order_date);
```

### 使えるケース
```sql
WHERE customer_id = 1                          -- ✅
WHERE customer_id = 1 AND order_date = '2024-01-01'  -- ✅
```

### 使えないケース
```sql
WHERE order_date = '2024-01-01'  -- ❌ 先頭列がない
```

### 原則
```
左から順に使われる
先頭の列が条件にないと効かない
```

---

## インデックスが使えない時の対処

### 1. UI設計で対処
```
「1年分まとめて検索」→ 選択率高い → 効かない
「1ヶ月ずつ検索」→ 選択率低い → 効く
```

### 2. データマート
```
大きいテーブル → 集計済みの小さいテーブルを作る
```

### 3. カバリングインデックス
```sql
-- SELECT句の列もインデックスに含める
CREATE INDEX idx ON orders(shop_id, order_id, receive_date);
-- → テーブル本体にアクセスせず完結
```
