-- Query 01: calculate total visit, pageview, transaction for Jan, Feb and March 2017 (order by month)
SELECT
  LEFT(date, 6) AS month
  ,SUM(totals.visits) AS visits
  ,SUM(totals.pageviews) AS pageviews
  ,SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month;

-- Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit) (order by total_visit DESC)
SELECT
  source
  ,visits
  ,total_no_of_bounces
  ,ROUND(total_no_of_bounces*100.0/visits,3) AS bounce_rate
FROM
  (SELECT
    trafficSource.source AS source
    ,SUM(totals.visits) AS visits
    ,SUM(totals.bounces) AS total_no_of_bounces
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
  GROUP BY source
  ORDER BY visits DESC);

-- Query 03: Revenue by traffic source by week, by month in June 2017
WITH mth AS(
  SELECT
    'Month' AS time_type
    ,'201706' AS time
    ,trafficSource.source AS source
    ,SUM(CASE WHEN productRevenue IS NULL THEN 0 ELSE productRevenue END)/pow(10,6) AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) hits,
    UNNEST(product) product
  GROUP BY source),
wk AS(
  SELECT
    'Week' AS time_type
    ,CONCAT('2017',EXTRACT(WEEK FROM PARSE_DATE("%Y%m%d",date))) AS time
    ,trafficSource.source AS source
    ,SUM(CASE WHEN productRevenue IS NULL THEN 0 ELSE productRevenue END)/pow(10,6) AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) hits,
    UNNEST(product) product
  WHERE productRevenue IS NOT NULL
  GROUP BY source, time)
SELECT
 *
FROM
  (SELECT * FROM mth
  UNION ALL
  SELECT * FROM wk)
ORDER BY source, time_type, time;

-- Query 04: Conversion rate by traffic source in 2017. (order by conversion_rate desc)
SELECT
  *
  ,FORMAT("%.2f%%",ROUND(transactions * 100.0 / visits, 2)) AS conversion_rate
FROM
  (
    SELECT
      trafficSource.source AS source,
      SUM(totals.visits) AS visits,
      SUM(
        CASE
          WHEN totals.transactions IS NOT NULL THEN totals.transactions
          ELSE 0
          END) AS transactions
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
    GROUP BY source
    HAVING SUM(totals.transactions) >= 50
  )
ORDER BY conversion_rate DESC;

-- Query 05: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017.
WITH
  pur AS (  -- purchaser
    SELECT
      LEFT(date, 6) AS month
      ,SUM(totals.pageviews) / COUNT(DISTINCT fullVisitorId)
        AS avg_pageviews_purchase
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST(hits) hits,
      UNNEST(product) product
    WHERE
      _table_suffix BETWEEN '0601' AND '0731'
      AND totals.transactions >= 1
      AND productRevenue IS NOT NULL
    GROUP BY month
  ),
  nonpur AS (  -- non purchaser
    SELECT
      LEFT(date, 6) AS month
      ,SUM(totals.pageviews) / COUNT(DISTINCT fullVisitorId)
        AS avg_pageviews_non_purchase
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST(hits) hits,
      UNNEST(product) product
    WHERE
      _table_suffix BETWEEN '0601' AND '0731'
      AND totals.transactions IS NULL
      AND productRevenue IS NULL
    GROUP BY month
  )
SELECT
  p.month
  ,avg_pageviews_purchase
  ,avg_pageviews_non_purchase
FROM pur AS p
INNER JOIN nonpur AS n
  USING (month)
ORDER BY month;

-- Query 06: Average number of transactions per user that made a purchase in July 2017
SELECT
  '201707' AS Month
  ,SUM(
    CASE
      WHEN totals.transactions IS NOT NULL THEN totals.transactions
      ELSE 0
      END)
    / COUNT(DISTINCT fullVisitorId) AS Avg_total_transactions_per_user
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) hits,
  UNNEST(product) product
WHERE
  totals.transactions >= 1
  AND productRevenue IS NOT NULL;

-- Query 07: Revenue contribution by device (desktop,mobile...) (order by ratio desc)
WITH
  rev AS (
    SELECT
      device.deviceCategory AS device
      ,ROUND(SUM(productRevenue) / pow(10, 6), 2) AS revenue_by_device
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_*`,
      UNNEST(hits) hits,
      UNNEST(product) product
    WHERE
      totals.transactions IS NOT NULL
      AND product.productRevenue IS NOT NULL
    GROUP BY device
  )
SELECT
  *,
  SUM(revenue_by_device) OVER () AS total_revenue
  ,ROUND(revenue_by_device * 100.0 / (SELECT SUM(revenue_by_device) FROM rev), 2)
    AS ratio
FROM rev
ORDER BY ratio DESC;

-- Query 08: Other products purchased by customers who purchased the product "YouTube Men's Vintage Henley" in July 2017. Output should show product name and the quantity was ordered.
SELECT DISTINCT    
  (v2ProductName) AS other_purchased_products
  ,SUM(productQuantity) AS quantity
FROM
  `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) hits,
  UNNEST(product) product
WHERE
  fullVisitorId IN ( -- Subquery to get customer who purchased YT men vintage Henley
    SELECT fullVisitorId
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
      UNNEST(hits) hits,
      UNNEST(product) product
    WHERE
      v2ProductName = 'YouTube Men\'s Vintage Henley'
      AND product.productRevenue IS NOT NULL
      AND totals.transactions >= 1
  )
  AND v2ProductName <> 'YouTube Men\'s Vintage Henley'
  AND product.productRevenue IS NOT NULL
  AND totals.transactions >= 1
GROUP BY other_purchased_products
ORDER BY quantity DESC;

-- Query 09: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and March 2017. For example, 100% product view then 40% add_to_cart and 10% purchase.
WITH
  smr AS (
    SELECT
      LEFT(date, 6) AS month
      ,SUM(CASE WHEN eCommerceAction.action_type = '2' THEN 1 ELSE 0 END)
        AS num_product_view
      ,SUM(CASE WHEN eCommerceAction.action_type = '3' THEN 1 ELSE 0 END)
        AS num_addtocart
      ,SUM(
        CASE WHEN eCommerceAction.action_type = '6' 
                  AND product.productRevenue IS NOT NULL 
                  THEN 1 ELSE 0 END)
        AS num_purchase
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST(hits) hits,
      UNNEST(product) product
    WHERE _table_suffix BETWEEN '0101' AND '0331'
    GROUP BY LEFT(date, 6)
    ORDER BY month
  )
SELECT
  *
  ,ROUND(num_addtocart * 100.0 / num_product_view, 2) AS add_to_cart_rate
  ,ROUND(num_purchase * 100.0 / num_product_view, 2) AS purchase_rate
FROM smr;

-- Query 10: Calculate revenue by week from May to July 2017 and cumulative revenue.
WITH
  rev AS (
    SELECT
      CONCAT('2017', '-', EXTRACT(WEEK FROM PARSE_DATE("%Y%m%d", date))) AS week
      ,ROUND(SUM(productRevenue) / pow(10, 6), 2) AS weekly_revenue
    FROM
      `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST(hits) hits,
      UNNEST(product) product
    WHERE
      _table_suffix BETWEEN '0501' AND '0731'
      AND productRevenue IS NOT NULL
    GROUP BY week
    ORDER BY week
  )
SELECT
  *
  ,SUM(weekly_revenue)
    OVER (ORDER BY week ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
    AS cumulative_revenue
FROM rev
ORDER BY week;