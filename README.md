# [SQL] Ecommerce data EDA
# Table of contents
[**I. Introduction**](#i-introduction)

[**II. Requirements**](#ii-requirements)

[**III. Dataset Access**](#iii-dataset-access)

[**IV. Overview**](#iv-overview)

[**V. Business questions**](#v-business-questions)

[**VI. Exploring the Dataset**](#vi-exploring-the-dataset)

[**VII. Summary**](#vii-summary)
# I. Introduction
This project contains an eCommerce dataset that I will explore using SQL on Google BigQuery. The dataset is based on the Google Analytics public dataset and contains data from an eCommerce website.

# II. Requirements
- [Google Cloud Platform account](https://cloud.google.com/)
- Project on Google Cloud Platform
- [Google BigQuery API](https://cloud.google.com/bigquery/docs/enable-transfer-service#:~:text=Enable%20the%20BigQuery%20Data%20Transfer%20Service,-Before%20you%20can&text=Open%20the%20BigQuery%20Data%20Transfer,Click%20the%20ENABLE%20button.) enabled
- [SQL query editor](https://cloud.google.com/monitoring/mql/query-editor) or IDE

# III. Dataset Access
The eCommerce dataset is stored in a public Google BigQuery dataset. To access the dataset, follow these steps:

- Log in to your Google Cloud Platform account and create a new project.
- Navigate to the BigQuery console and select your newly created project.
- In the navigation panel, select "Add Data" and then "Search a project".
- Enter the project ID **"bigquery-public-data.google_analytics_sample.ga_sessions"** and click "Enter".
- Click on the **"ga_sessions_"** table to open it.

# IV. Overview:
The dataset contains Google Analytics data from the Google Merchandise Store, a real ecommerce store. The Google Merchandise Store sells Google branded merchandise. It includes the following kinds of information:
- Traffic source data: information about where website visitors originate. This includes data about organic traffic, paid search traffic, display traffic, etc.
- Content data: information about the behavior of users on the site. This includes the URLs of pages that visitors look at, how they interact with content, etc.
- Transactional data: information about the transactions that occur on the Google Merchandise Store website.

# V. Business questions:
Explore and analyze key e-commerce metrics, then provide insights and recommendations.

# VI. Exploring the Dataset

## **Query 01: Calculate total visit, pageview, transaction for Jan, Feb and March 2017**
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

**Insight:** Transactions grew steadily over the quarter, with a significant spike in March that drove both the highest volume of visits and the strongest conversion rate.

**Recommend:** Analyze the specific marketing campaigns or product launches implemented in March to identify the drivers of this growth and replicate those strategies in future months.

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

**Insight:** Reddit demonstrates the highest user engagement with a significantly lower bounce rate (28.57%) compared to high-volume sources like Google and YouTube.

**Recommend:** Scale targeted marketing efforts on Reddit to capitalize on this high-intent traffic and increase the overall volume of engaged visitors.

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

**Insight:** Direct traffic is the sole driver of revenue in this period, while all other acquisition channels are currently failing to generate any sales.

**Recommend:** Audit the conversion funnels and landing pages for underperforming channels, particularly paid sources like Adwords, to identify why they are not converting.

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

**Insight:** While Google drives a massive volume of traffic, its conversion rate (0.92%) is significantly lower than both direct and DFA channels.

**Recommend:** Review Google's keyword targeting and landing page relevance to better align incoming traffic with user intent and improve the conversion rate.

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
  ,ROUND(avg_pageviews_purchase,2) AS avg_pageviews_purchase
  ,ROUND(avg_pageviews_non_purchase,2) AS avg_pageviews_non_purchase
FROM pur AS p
INNER JOIN nonpur AS n
  USING (month)
ORDER BY month;
```
- Result:
<img width="808" height="172" alt="Screenshot 2026-10-16 093539" src="https://github.com/user-attachments/assets/df73fcf2-afa0-40ab-ad02-943b09b7043c" />

**Insight:** Non-purchasing users browse significantly more pages than those who convert, indicating that higher engagement in browsing does not necessarily correlate with a higher likelihood of purchase.

**Recommend:** Analyze the navigation paths of these high-engagement non-purchasers to identify potential friction points and implement targeted nudges to streamline their path to purchase.

## **Query 06: Average number of transactions per user that made a purchase in July 2017**
- SQL code:
```SQL
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
```
- Result:
<img width="615" height="131" alt="Screenshot 2026-10-16 093740" src="https://github.com/user-attachments/assets/7eacaa36-240b-490f-981f-d605b2cfaeed" />

## **Query 07: Revenue contribution by device (desktop,mobile...) in 2017**
- SQL code:
```SQL
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
```
- Result:
<img width="802" height="187" alt="image" src="https://github.com/user-attachments/assets/03ed9d5f-7c9e-4cd6-80b3-7c3a9bba31c9" />

**Insight:** Desktop leads device revenue at 167,474.74, well ahead of mobile at 56,553.10 and tablet at 10,748.13.

**Recommend:** Prioritize improving mobile and tablet conversion.

## **Query 08: Other products purchased by customers who purchased product "YouTube Men's Vintage Henley" in July 2017**
- SQL code:
```SQL
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
```
- Result
<img width="550" height="542" alt="image" src="https://github.com/user-attachments/assets/5b8f3a70-9da1-4830-8b9d-2106757be229" />

**Insight:** Google Sunglasses is the most frequently co-purchased item, with 20 purchases—nearly three times the next item’s 7.

**Recommend:** Feature Google Sunglasses in cross-sell recommendations and test pairing it with the next most frequently co-purchased products.

## **Query 09: Calculate cohort map from product view to addtocart to purchase in Jan, Feb and Mar 2017**
- SQL code:
```SQL
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
```
- Result:
<img width="1107" height="192" alt="image" src="https://github.com/user-attachments/assets/b38a019d-913f-403a-9b4e-36a66605e83d" />

**Insight:** From January to March 2017, add-to-cart and purchase rates rose steadily, with March reaching the highest purchase rate at 12.64%.

**Recommend:** Identify what improved the customer journey by March and apply those changes to sustain the conversion gains.

## **Query 10: Calculate revenue by week from May to July 2017 and culmulative revenue**
- SQL code:
```SQL
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
```
- Result:
<img width="647" height="527" alt="image" src="https://github.com/user-attachments/assets/de42120e-76db-494f-8cf4-ac1b2f066da6" />

**Insight:** Weekly revenue fluctuated, peaking at 56,675.36 in week 2017-29 after a sharp rise from 42,013.08 in week 2017-28.

**Recommend:** Investigate what drove the week 2017-28–29 increase and test similar promotions or merchandising strategies in future weeks.

# VII. Summary:
| Insight                                                                                                                                                                                               | Recommend                                                                                                                                                                            |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Transactions   grew steadily over the quarter, with a significant spike in March that drove   both the highest volume of visits and the strongest conversion rate.                                    | Analyze the   specific marketing campaigns or product launches implemented in March to   identify the drivers of this growth and replicate those strategies in future   months.      |
| Reddit   demonstrates the highest user engagement with a significantly lower bounce   rate (28.57%) compared to high-volume sources like Google and YouTube.                                          | Scale targeted   marketing efforts on Reddit to capitalize on this high-intent traffic and   increase the overall volume of engaged visitors.                                        |
| Direct   traffic is the sole driver of revenue in this period, while all other   acquisition channels are currently failing to generate any sales.                                                    | Audit the   conversion funnels and landing pages for underperforming channels,   particularly paid sources like Adwords, to identify why they are not   converting.                  |
| While   Google drives a massive volume of traffic, its conversion rate (0.92%) is   significantly lower than both direct and DFA channels.                                                            | Review   Google's keyword targeting and landing page relevance to better align   incoming traffic with user intent and improve the conversion rate.                                  |
| Non-purchasing   users browse significantly more pages than those who convert, indicating that   higher engagement in browsing does not necessarily correlate with a higher   likelihood of purchase. | Analyze the   navigation paths of these high-engagement non-purchasers to identify   potential friction points and implement targeted nudges to streamline their   path to purchase. |
| Desktop   leads device revenue at 167,474.74, well ahead of mobile at 56,553.10 and   tablet at 10,748.13.                                                                                            | Prioritize   improving mobile and tablet conversion.                                                                                                                                 |
| Google   Sunglasses is the most frequently co-purchased item, with 20 purchases—nearly   three times the next item’s 7.                                                                               | Feature Google   Sunglasses in cross-sell recommendations and test pairing it with the next   most frequently co-purchased products.                                                 |
| From   January to March 2017, add-to-cart and purchase rates rose steadily, with   March reaching the highest purchase rate at 12.64%.                                                                | Identify   what improved the customer journey by March and apply those changes to   sustain the conversion gains.                                                                    |
| Weekly   revenue fluctuated, peaking at 56,675.36 in week 2017-29 after a sharp rise   from 42,013.08 in week 2017-28.                                                                                | Investigate   what drove the week 2017-28–29 increase and test similar promotions or   merchandising strategies in future weeks.                                                     |
