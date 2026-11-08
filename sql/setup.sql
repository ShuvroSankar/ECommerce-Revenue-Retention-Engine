-- =====================================================================
-- E-Commerce Revenue & Retention Engine: full setup
-- Run in the BigQuery console with your NEW project selected.
-- Source data: bigquery-public-data.thelook_ecommerce (US multi-region),
-- so the dataset below MUST be created in the US location.
-- Creates dataset `retention_engine` and four views.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS retention_engine
OPTIONS (location = 'US');


-- ---------------------------------------------------------------------
-- 1. Monthly revenue timeline  (feeds the revenue trend / forecast)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW retention_engine.v_monthly_revenue_timeline AS
SELECT
  TIMESTAMP_TRUNC(created_at, MONTH) AS order_month,
  -- Original (misspelled) column name kept so existing Looker Studio fields still match
  ROUND(SUM(sale_price), 2) AS monthy_revenue,
  -- Correctly spelled alias, for use after the dashboard is restored
  ROUND(SUM(sale_price), 2) AS monthly_revenue
FROM `bigquery-public-data.thelook_ecommerce.order_items`
WHERE status NOT IN ('Cancelled', 'Returned')
GROUP BY order_month;


-- ---------------------------------------------------------------------
-- 2. RFM customer segments
--    Changes vs. the original:
--      * Recency is measured from the dataset's latest order, not
--        CURRENT_TIMESTAMP(), so results are reproducible day to day.
--      * Frequency is scored from the actual order count. NTILE(5) split
--        customers with identical order counts across different buckets
--        (about 6,100 one-order customers received f_score 4).
--      * Seven segments replace the old catch-all 'Other' (72% of customers).
--      * user_id tiebreakers make recency/monetary scoring deterministic.
--    Output columns are unchanged, so Looker Studio fields still match.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW retention_engine.v_customer_rfm_segments AS
WITH user_info AS (
  SELECT
    user_id,
    TIMESTAMP_DIFF(
      (SELECT MAX(created_at) FROM `bigquery-public-data.thelook_ecommerce.order_items`),
      MAX(created_at),
      DAY
    ) AS recency_days,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(sale_price), 2) AS total_spend
  FROM `bigquery-public-data.thelook_ecommerce.order_items`
  WHERE status NOT IN ('Cancelled', 'Returned')
  GROUP BY user_id
),

ranked_user_info AS (
  SELECT
    user_id,
    recency_days,
    total_orders,
    total_spend,
    NTILE(5) OVER (ORDER BY recency_days DESC, user_id) AS r_score,
    CASE
      WHEN total_orders = 1 THEN 1
      WHEN total_orders = 2 THEN 3
      WHEN total_orders = 3 THEN 4
      ELSE 5
    END AS f_score,
    NTILE(5) OVER (ORDER BY total_spend ASC, user_id) AS m_score
  FROM user_info
)

SELECT *,
  CASE
    WHEN f_score >= 4 AND r_score >= 4 AND m_score >= 4 THEN 'Champions'
    WHEN f_score >= 4 AND r_score <= 2 AND m_score >= 4 THEN 'Can\'t Lose Them'
    WHEN f_score >= 3 AND r_score <= 2                  THEN 'At Risk'
    WHEN f_score >= 3                                   THEN 'Loyal Customers'
    WHEN r_score >= 4                                   THEN 'New Customers'
    WHEN r_score = 3                                    THEN 'Promising'
    ELSE 'Hibernating'
  END AS customer_segment
FROM ranked_user_info;


-- ---------------------------------------------------------------------
-- 3. Product profit margins
--    Changes vs. the original file:
--      * removed LIMIT 5 (no ORDER BY, so it returned 5 arbitrary categories)
--      * added the status filter the README says is applied
--      * added ORDER BY so the best categories come first
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW retention_engine.v_product_profit_margins AS
SELECT
  products.category,
  ROUND(SUM(items.sale_price), 2) AS total_price,
  ROUND(SUM(products.cost), 2) AS total_inventory_cost,
  ROUND(SUM(items.sale_price) - SUM(products.cost), 2) AS gross_profit_usd,
  ROUND((SUM(items.sale_price) - SUM(products.cost)) / SUM(items.sale_price) * 100, 2) AS gross_profit_margin
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS items
INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS products
  ON items.product_id = products.id
WHERE items.status NOT IN ('Cancelled', 'Returned')
GROUP BY products.category
ORDER BY gross_profit_usd DESC;


-- ---------------------------------------------------------------------
-- 4. Cohort retention  (logic unchanged; not currently used in the dashboard)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW retention_engine.v_customer_cohort_retention AS
WITH row_cohort AS (
  SELECT
    user_id,
    DATE(TIMESTAMP_TRUNC(created_at, MONTH)) AS order_month,
    DATE(TIMESTAMP_TRUNC(MIN(created_at) OVER (PARTITION BY user_id), MONTH)) AS cohort_month
  FROM `bigquery-public-data.thelook_ecommerce.orders`
)

SELECT
  cohort_month,
  DATE_DIFF(order_month, cohort_month, MONTH) AS month_since_first_purchase,
  COUNT(DISTINCT user_id) AS active_returning_users
FROM row_cohort
GROUP BY cohort_month, month_since_first_purchase
ORDER BY cohort_month, month_since_first_purchase;
