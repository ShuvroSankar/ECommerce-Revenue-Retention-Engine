--  Base Aggregations 
WITH user_info AS 
(
SELECT
  user_id,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(created_at), DAY) AS recency_days,
  COUNT(DISTINCT order_id) AS total_orders,
  ROUND(SUM(sale_price), 2) AS total_spend
FROM `bigquery-public-data.thelook_ecommerce.order_items` 
WHERE status NOT IN ('Cancelled', 'Returned')
GROUP BY user_id
),

-- The Ranking Layer 

ranked_user_info AS 
(
SELECT
  user_id,
  recency_days,
  total_orders,
  total_spend,
  NTILE(5) OVER(ORDER BY  recency_days DESC) AS r_score,
  NTILE(5) OVER(ORDER BY total_orders ASC) AS f_score,
  NTILE(5) OVER(ORDER BY total_spend ASC) AS m_score 
FROM user_info
)

SELECT *,
  CASE 
    WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'Can\'t Lose Them'
    WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
    ELSE 'Other' -- Handles any customer who doesn't match the rules above
  END AS customer_segment
FROM ranked_user_info;

