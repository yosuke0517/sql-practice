■リストC.1::男女別の年齢ランキング（飛び番あり）を降順に出力するSELECT文
SELECT name,
       sex,
       age,
       RANK() OVER(PARTITION BY sex ORDER BY age DESC) rnk_desc
  FROM Address;

■リストC.2::累計の逆算
SELECT month_id, month_name,
       cumulative_sales - COALESCE(LAG(cumulative_sales, 1)
                             OVER (ORDER BY month_id), 0) AS monthly_sales
  FROM MonthlySales;

■リストC.3::昇順と降順それぞれでソートしたROW_NUMBERの結果
SELECT student_id,
       weight, 
       ROW_NUMBER() OVER (ORDER BY weight ASC)  AS hi,
       ROW_NUMBER() OVER (ORDER BY weight DESC) AS lo
  FROM Weights;

■リストC.4::NOT NULL制約の列も更新可能なUPDATE文
UPDATE ScoreRowsNN
   SET score = (SELECT COALESCE(CASE ScoreRowsNN.subject 
                                     WHEN '英語' THEN score_en
                                     WHEN '国語' THEN score_nl
                                     WHEN '数学' THEN score_mt
                                     ELSE NULL
                                 END, 0)
                  FROM ScoreCols
                 WHERE student_id = ScoreRowsNN.student_id);

■リストC.5::NOT NULL制約の列も更新可能なUPDATE文：その2
UPDATE ScoreRowsNN
   SET score = COALESCE((SELECT CASE ScoreRowsNN.subject 
                                     WHEN '英語' THEN score_en
                                     WHEN '国語' THEN score_nl
                                     WHEN '数学' THEN score_mt
                                     ELSE NULL
                                 END
                  FROM ScoreCols
                 WHERE student_id = ScoreRowsNN.student_id), 0);

