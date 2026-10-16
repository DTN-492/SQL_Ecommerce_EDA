# [SQL] Ecommerce data EDA
Utilized SQL in Google BigQuery to write and execute queries to find the valuable insights
I. Introduction
This project contains an eCommerce dataset that I will explore using SQL on Google BigQuery. The dataset is based on the Google Analytics public dataset and contains data from an eCommerce website.

II. Requirements
Google Cloud Platform account
Project on Google Cloud Platform
Google BigQuery API enabled
SQL query editor or IDE
III. Dataset Access
The eCommerce dataset is stored in a public Google BigQuery dataset. To access the dataset, follow these steps:

Log in to your Google Cloud Platform account and create a new project.
Navigate to the BigQuery console and select your newly created project.
In the navigation panel, select "Add Data" and then "Search a project".
Enter the project ID "bigquery-public-data.google_analytics_sample.ga_sessions" and click "Enter".
Click on the "ga_sessions_" table to open it.

IV. Exploring the Dataset
In this project, I will write 08 query in Bigquery base on Google Analytics dataset

*Query 01: calculate total visit, pageview, transaction for Jan, Feb and March 2017 (order by month)*
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
