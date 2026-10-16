# [SQL] Ecommerce data EDA
Utilized SQL in Google BigQuery to write and execute queries to find the valuable insights
# I. Introduction
This project contains an eCommerce dataset that I will explore using SQL on Google BigQuery. The dataset is based on the Google Analytics public dataset and contains data from an eCommerce website.

# II. Requirements
Google Cloud Platform account
Project on Google Cloud Platform
Google BigQuery API enabled
SQL query editor or IDE

# III. Dataset Access
The eCommerce dataset is stored in a public Google BigQuery dataset. To access the dataset, follow these steps:

Log in to your Google Cloud Platform account and create a new project.
Navigate to the BigQuery console and select your newly created project.
In the navigation panel, select "Add Data" and then "Search a project".
Enter the project ID "bigquery-public-data.google_analytics_sample.ga_sessions" and click "Enter".
Click on the "ga_sessions_" table to open it.

# IV. Exploring the Dataset
In this project, I will write 08 query in Bigquery base on Google Analytics dataset

## **Query 01: calculate total visit, pageview, transaction for Jan, Feb and March 2017**
- SQL code:
```SQL
SELECT
  LEFT(date, 6) AS month
  ,SUM(totals.visits) AS visits
  ,SUM(totals.pageviews) AS pageviews
  ,SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month;
```
- Result:
<img width="810" height="200" alt="image" src="https://github.com/user-attachments/assets/9a1af333-d17b-433a-8da8-75fd58b51514" />

## **Query 02: Bounce rate per traffic source in July 2017 (Bounce_rate = num_bounce/total_visit)**
- SQL code:
```SQL
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
```
- Result:
<img width="815" height="545" alt="image" src="https://github.com/user-attachments/assets/287d32d8-3546-4319-a789-5bce7d24f9aa" />

## **Query 03: Revenue by traffic source by week, by month in June 2017**
- SQL code:
```SQL
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
```
- Result:
<img width="990" height="512" alt="image" src="https://github.com/user-attachments/assets/2692f372-74d9-4f14-aec5-c387d517eaa6" />

## **Query 04: Conversion rate by traffic source in 2017**
- SQL code:
```SQL
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
```
- Result:
<img width="897" height="192" alt="image" src="https://github.com/user-attachments/assets/df9fbe34-38f8-435a-8370-5ff61c5da91e" />

## **Query 05: Average number of pageviews by purchaser type (purchasers vs non-purchasers) in June, July 2017**
- SQL code:
```SQL
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
```
- Result:



