SELECT
  TIMESTAMP_TRUNC(created_at, MONTH) as order_month,
  ROUND(SUM(sale_price), 2) as monthy_revenue
FROM `bigquery-public-data.thelook_ecommerce.order_items`
WHERE status NOT IN ('Cancelled', 'Returned')
GROUP BY order_month
