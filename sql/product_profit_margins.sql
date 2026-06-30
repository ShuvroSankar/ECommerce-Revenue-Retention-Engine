SELECT  
  products.category,
  ROUND(SUM(items.sale_price),2) AS total_price,
  ROUND(SUM(products.cost), 2) AS total_inventory_cost,
  ROUND(SUM(items.sale_price) - SUM(products.cost), 2) AS gross_profit_usd,
  -- Safely aliased calculation
  ROUND((SUM(items.sale_price) - SUM(products.cost)) / SUM(items.sale_price) * 100, 2) AS gross_profit_margin
FROM `bigquery-public-data.thelook_ecommerce.order_items` AS items
INNER JOIN `bigquery-public-data.thelook_ecommerce.products` AS products
  -- CRITICAL FIX: Links items directly to their structural product details
  ON items.product_id = products.id
GROUP BY products.category
LIMIT 5

