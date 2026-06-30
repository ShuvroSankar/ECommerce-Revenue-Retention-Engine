WITH row_cohort AS (
SELECT 
  user_id,
  DATE(TIMESTAMP_TRUNC(created_at, MONTH)) AS order_month,
  DATE(TIMESTAMP_TRUNC(MIN(created_at) OVER(PARTITION BY user_id), MONTH)) AS cohort_month

FROM `bigquery-public-data.thelook_ecommerce.orders` 
)

SELECT
  cohort_month,
  DATE_DIFF(order_month, cohort_month, MONTH) AS month_since_first_purchase,
  COUNT( DISTINCT user_id) AS active_returning_users
FROM row_cohort 
GROUP BY cohort_month, month_since_first_purchase
ORDER BY cohort_month, month_since_first_purchase
