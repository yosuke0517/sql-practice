■「図5.1::売り上げ計算を行うテーブルのサンプル」を作成

CREATE TABLE Sales
(company CHAR(1) NOT NULL,
 year    INTEGER NOT NULL , 
 sale    INTEGER NOT NULL , 
   CONSTRAINT pk_sales PRIMARY KEY (company, year));

INSERT INTO Sales VALUES ('A', 2002, 50);
INSERT INTO Sales VALUES ('A', 2003, 52);
INSERT INTO Sales VALUES ('A', 2004, 55);
INSERT INTO Sales VALUES ('A', 2007, 55);
INSERT INTO Sales VALUES ('B', 2001, 27);
INSERT INTO Sales VALUES ('B', 2005, 28);
INSERT INTO Sales VALUES ('B', 2006, 28);
INSERT INTO Sales VALUES ('B', 2009, 30);
INSERT INTO Sales VALUES ('C', 2001, 40);
INSERT INTO Sales VALUES ('C', 2005, 39);
INSERT INTO Sales VALUES ('C', 2006, 38);
INSERT INTO Sales VALUES ('C', 2010, 35);

CREATE TABLE Sales2
(company CHAR(1) NOT NULL,
 year    INTEGER NOT NULL , 
 sale    INTEGER NOT NULL , 
 var     CHAR(1) ,
   CONSTRAINT pk_sales2 PRIMARY KEY (company, year));


■リスト5.3 これ以上ないぐらい単純なSQL文
CREATE TABLE Foo 
( p_key INTEGER PRIMARY KEY,
  col_a INTEGER );

SELECT col_a FROM Foo WHERE p_key = 1;


■リスト5.4 ウィンドウ関数を使った解
INSERT INTO Sales2
SELECT company,
       year,
       sale,
       CASE SIGN(sale - MAX(sale)
                         OVER ( PARTITION BY company
                                    ORDER BY year
                                     ROWS BETWEEN 1 PRECEDING
                                              AND 1 PRECEDING) )
       WHEN 0 THEN '='
       WHEN 1 THEN '+'
       WHEN -1 THEN '-'
       ELSE NULL END AS var
  FROM Sales;


■リスト5.5 ウィンドウ関数で「1行前の会社名」と「1行前の売り上げ」を取得
SELECT company,
       year,
       sale,
       MAX(company)
         OVER (PARTITION BY company
                   ORDER BY year
                    ROWS BETWEEN 1 PRECEDING
                             AND 1 PRECEDING) AS pre_company,
       MAX(sale)
         OVER (PARTITION BY company
                   ORDER BY year
                    ROWS BETWEEN 1 PRECEDING
                             AND 1 PRECEDING) AS pre_sale
  FROM Sales;


■リスト5.6::ウィンドウ関数でLAG関数を使って行を遡る
SELECT company,
       year,
       sale,
       LAG(company, 1) 
           OVER (PARTITION BY company
                     ORDER BY year) AS pre_company,
       LAG(sale, 1)
           OVER (PARTITION BY company
                     ORDER BY year) AS pre_sale
  FROM Sales;


■リスト5.7::ウィンドウの定義を一箇所にまとめる書き方
SELECT company,
       year,
       sale,
       LAG(company, 1) OVER W_PRE_YEAR AS pre_company,
       LAG(sale, 1)    OVER W_PRE_YEAR AS pre_sale
  FROM Sales
  WINDOW W_PRE_YEAR AS (PARTITION BY company
                            ORDER BY year);


■リスト5.8 郵便番号テーブルの定義
CREATE TABLE PostalCode
(pcode CHAR(7),
 district_name VARCHAR(256),
     CONSTRAINT pk_pcode PRIMARY KEY(pcode));

INSERT INTO PostalCode VALUES ('4130001',  '静岡県熱海市泉');
INSERT INTO PostalCode VALUES ('4130002',  '静岡県熱海市伊豆山');
INSERT INTO PostalCode VALUES ('4130103',  '静岡県熱海市網代');
INSERT INTO PostalCode VALUES ('4130041',  '静岡県熱海市青葉町');
INSERT INTO PostalCode VALUES ('4103213',  '静岡県伊豆市青羽根');
INSERT INTO PostalCode VALUES ('4380824',  '静岡県磐田市赤池');

■リスト5.9 郵便番号のランキングを求めるクエリ
SELECT pcode,
       CASE WHEN pcode = '4130033' THEN 0
            WHEN pcode LIKE '413003%' THEN 1
            WHEN pcode LIKE '41300%'  THEN 2
            WHEN pcode LIKE '4130%'   THEN 3
            WHEN pcode LIKE '413%'    THEN 4
            WHEN pcode LIKE '41%'     THEN 5
            WHEN pcode LIKE '4%'      THEN 6
            ELSE NULL END AS rank
  FROM PostalCode;


■リスト5.10 最寄の郵便番号を求めるクエリ
SELECT pcode,
       district_name
  FROM PostalCode
 WHERE CASE WHEN pcode = '4130033' THEN 0
            WHEN pcode LIKE '413003%' THEN 1
            WHEN pcode LIKE '41300%'  THEN 2
            WHEN pcode LIKE '4130%'   THEN 3
            WHEN pcode LIKE '413%'    THEN 4
            WHEN pcode LIKE '41%'     THEN 5
            WHEN pcode LIKE '4%'      THEN 6
            ELSE NULL END = 
                (SELECT MIN(CASE WHEN pcode = '4130033' THEN 0
                                 WHEN pcode LIKE '413003%' THEN 1
                                 WHEN pcode LIKE '41300%'  THEN 2
                                 WHEN pcode LIKE '4130%'   THEN 3
                                 WHEN pcode LIKE '413%'    THEN 4
                                 WHEN pcode LIKE '41%'     THEN 5
                                 WHEN pcode LIKE '4%'      THEN 6
                                 ELSE NULL END)
                   FROM PostalCode);

■リスト5.11 ウィンドウ関数による解
SELECT pcode,
       district_name
  FROM (SELECT pcode,
               district_name,
               CASE WHEN pcode = '4130033' THEN 0
                    WHEN pcode LIKE '413003%' THEN 1
                    WHEN pcode LIKE '41300%'  THEN 2
                    WHEN pcode LIKE '4130%'   THEN 3
                    WHEN pcode LIKE '413%'    THEN 4
                    WHEN pcode LIKE '41%'     THEN 5
                    WHEN pcode LIKE '4%'      THEN 6
                    ELSE NULL END AS hit_code,
               MIN(CASE WHEN pcode = '4130033' THEN 0
                        WHEN pcode LIKE '413003%' THEN 1
                        WHEN pcode LIKE '41300%'  THEN 2
                        WHEN pcode LIKE '4130%'   THEN 3
                        WHEN pcode LIKE '413%'    THEN 4
                        WHEN pcode LIKE '41%'     THEN 5
                        WHEN pcode LIKE '4%'      THEN 6
                        ELSE NULL END) 
                OVER(ORDER BY CASE WHEN pcode = '4130033' THEN 0
                                   WHEN pcode LIKE '413003%' THEN 1
                                   WHEN pcode LIKE '41300%'  THEN 2
                                   WHEN pcode LIKE '4130%'   THEN 3
                                   WHEN pcode LIKE '413%'    THEN 4
                                   WHEN pcode LIKE '41%'     THEN 5
                                   WHEN pcode LIKE '4%'      THEN 6
                                   ELSE NULL END) AS min_code
          FROM PostalCode) Foo
 WHERE hit_code = min_code;


■リスト5.12 郵便番号の履歴テーブルの定義
CREATE TABLE PostalHistory
(name  CHAR(1),
 pcode CHAR(7),
 new_pcode CHAR(7),
     CONSTRAINT pk_name_pcode PRIMARY KEY(name, pcode));

INSERT INTO PostalHistory VALUES ('A', '4130001', '4130002');
INSERT INTO PostalHistory VALUES ('A', '4130002', '4130103');
INSERT INTO PostalHistory VALUES ('A', '4130103', NULL     );
INSERT INTO PostalHistory VALUES ('B', '4130041', NULL     );
INSERT INTO PostalHistory VALUES ('C', '4103213', '4380824');
INSERT INTO PostalHistory VALUES ('C', '4380824', NULL     );


■リスト5.13 一番古い住所を検索する（PostgreSQLとMySQL）
WITH RECURSIVE Explosion (name, pcode, new_pcode, depth)
AS
(SELECT name, pcode, new_pcode, 1
   FROM PostalHistory 
  WHERE name = 'A'
    AND new_pcode IS NULL -- 探索の開始点
 UNION ALL
 SELECT Child.name, Child.pcode, Child.new_pcode, depth + 1
   FROM Explosion Parent, PostalHistory Child
  WHERE Parent.pcode = Child.new_pcode
    AND Parent.name = Child.name)
-- メインのSELECT文
SELECT name, pcode, new_pcode
  FROM Explosion
 WHERE depth = (SELECT MAX(depth)
                  FROM Explosion);


■リスト5.14::一番古い住所を検索する（Oracle限定）

SELECT pcode, new_pcode, LEVEL
  FROM PostalHistory
 WHERE name = 'A'
 START WITH new_pcode IS NULL
CONNECT BY PRIOR pcode = new_pcode;

■リスト5.15::売り上げ累計テーブル
CREATE TABLE MonthlySales (
  month_id INTEGER PRIMARY KEY,
  month_name VARCHAR(10),
  cumulative_sales INTEGER );

INSERT INTO MonthlySales VALUES (1, 'Jan', 5000);
INSERT INTO MonthlySales VALUES (2, 'Feb', 9500);
INSERT INTO MonthlySales VALUES (3, 'Mar', 15200);
INSERT INTO MonthlySales VALUES (4, 'Apr', 21900);
INSERT INTO MonthlySales VALUES (5, 'May', 29800);
INSERT INTO MonthlySales VALUES (6, 'Jun', 38700);

