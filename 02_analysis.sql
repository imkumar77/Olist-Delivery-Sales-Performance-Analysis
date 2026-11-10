-- =====================================================================
-- 02_analysis.sql | Each block starts with "-- name: <output_file>"
-- Skills shown: JOINs, CTEs, window functions (LAG, RANK, SUM OVER, NTILE),
-- conditional aggregation, self-contained cohorts.
-- Analysis window: 2017-01 to 2018-08 (2016 & Sep-Oct 2018 are too sparse)
-- =====================================================================

-- name: q01_headline_kpis
SELECT COUNT(*)                                  AS delivered_orders,
       COUNT(DISTINCT customer_unique_id)        AS unique_customers,
       ROUND(SUM(item_revenue), 0)               AS gmv_items,
       ROUND(SUM(freight), 0)                    AS freight_total,
       ROUND(SUM(item_revenue) / COUNT(*), 2)    AS aov,
       ROUND(100.0 * SUM(freight) / SUM(order_total), 1) AS freight_pct_of_total,
       ROUND(AVG(delivery_days), 1)              AS avg_delivery_days,
       ROUND(AVG(promised_days), 1)              AS avg_promised_days,
       ROUND(100.0 * AVG(is_late), 2)            AS late_rate_pct,
       ROUND(AVG(review_score), 2)               AS avg_review
FROM v_order_facts
WHERE order_month BETWEEN '2017-01' AND '2018-08';

-- name: q02_monthly_trend
WITH m AS (
    SELECT order_month,
           COUNT(*) AS orders,
           SUM(item_revenue) AS gmv,
           AVG(item_revenue) AS aov,
           AVG(is_late) AS late_rate,
           AVG(review_score) AS avg_review,
           AVG(delivery_days) AS avg_delivery_days
    FROM v_order_facts
    WHERE order_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY order_month
)
SELECT order_month, orders, ROUND(gmv,0) AS gmv, ROUND(aov,2) AS aov,
       ROUND(100.0*(gmv - LAG(gmv) OVER (ORDER BY order_month)) / LAG(gmv) OVER (ORDER BY order_month), 1) AS gmv_mom_pct,
       ROUND(100*late_rate,2) AS late_rate_pct, ROUND(avg_review,2) AS avg_review,
       ROUND(avg_delivery_days,1) AS avg_delivery_days,
       ROUND(SUM(gmv) OVER (ORDER BY order_month), 0) AS cumulative_gmv
FROM m ORDER BY order_month;

-- name: q03_late_vs_review
-- How much does lateness cost in customer satisfaction?
SELECT CASE WHEN is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*)                                   AS orders,
       ROUND(AVG(review_score), 2)                AS avg_review,
       ROUND(100.0 * AVG(review_score <= 2), 1)   AS pct_negative_1_2_star,
       ROUND(100.0 * AVG(review_score = 5), 1)    AS pct_5_star
FROM v_order_facts
WHERE order_month BETWEEN '2017-01' AND '2018-08' AND review_score IS NOT NULL
GROUP BY is_late;

-- name: q04_review_by_delay_bucket
WITH b AS (
  SELECT review_score,
    CASE WHEN days_vs_promise <= -7 THEN '1. 7+ days early'
         WHEN days_vs_promise <= 0  THEN '2. 0-7 days early'
         WHEN days_vs_promise <= 3  THEN '3. 1-3 days late'
         WHEN days_vs_promise <= 7  THEN '4. 4-7 days late'
         WHEN days_vs_promise <= 14 THEN '5. 8-14 days late'
         ELSE '6. 15+ days late' END AS bucket
  FROM v_order_facts
  WHERE order_month BETWEEN '2017-01' AND '2018-08' AND review_score IS NOT NULL)
SELECT bucket, COUNT(*) AS orders, ROUND(AVG(review_score),2) AS avg_review,
       ROUND(100.0*AVG(review_score<=2),1) AS pct_negative
FROM b GROUP BY bucket ORDER BY bucket;

-- name: q05_repeat_purchase_by_first_order_experience
-- Do customers whose FIRST order was late come back less often?
WITH ranked AS (
    SELECT customer_unique_id, order_id, is_late, review_score,
           ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY purchased_at) AS rn,
           COUNT(*)     OVER (PARTITION BY customer_unique_id)                       AS total_orders
    FROM v_order_facts
    WHERE order_month BETWEEN '2017-01' AND '2018-02'   -- 6+ months follow-up window
), first_orders AS (SELECT * FROM ranked WHERE rn = 1)
SELECT CASE WHEN is_late = 1 THEN 'First order late' ELSE 'First order on time' END AS first_order,
       COUNT(*) AS customers,
       SUM(total_orders > 1) AS repeat_customers,
       ROUND(100.0 * AVG(total_orders > 1), 2) AS repeat_rate_pct
FROM first_orders GROUP BY is_late;

-- name: q06_state_performance
SELECT customer_state AS state,
       COUNT(*) AS orders,
       ROUND(SUM(item_revenue),0) AS gmv,
       ROUND(AVG(delivery_days),1) AS avg_delivery_days,
       ROUND(AVG(freight),1) AS avg_freight,
       ROUND(100.0*SUM(freight)/SUM(order_total),1) AS freight_pct,
       ROUND(100.0*AVG(is_late),1) AS late_rate_pct,
       ROUND(AVG(review_score),2) AS avg_review
FROM v_order_facts
WHERE order_month BETWEEN '2017-01' AND '2018-08'
GROUP BY customer_state
HAVING COUNT(*) >= 100
ORDER BY late_rate_pct DESC;

-- name: q07_category_performance
WITH c AS (
    SELECT category,
           COUNT(DISTINCT order_id) AS orders,
           SUM(price) AS gmv,
           AVG(is_late) AS late_rate,
           AVG(review_score) AS avg_review,
           AVG(freight_value / NULLIF(price,0)) AS freight_ratio
    FROM v_item_facts
    WHERE order_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY category HAVING COUNT(DISTINCT order_id) >= 300
)
SELECT category, orders, ROUND(gmv,0) AS gmv,
       ROUND(100.0*gmv/SUM(gmv) OVER (),1) AS gmv_share_pct,
       ROUND(100*late_rate,1) AS late_rate_pct, ROUND(avg_review,2) AS avg_review,
       ROUND(100*freight_ratio,1) AS avg_freight_pct_of_price,
       RANK() OVER (ORDER BY gmv DESC) AS gmv_rank,
       RANK() OVER (ORDER BY avg_review ASC) AS worst_review_rank
FROM c ORDER BY gmv DESC;

-- name: q08_seller_scorecard
-- Seller-level scorecard (min 30 orders). Pareto share + risk flags via window functions.
WITH s AS (
    SELECT seller_id, seller_state,
           COUNT(DISTINCT order_id) AS orders,
           SUM(price) AS gmv,
           AVG(is_late) AS late_rate,
           AVG(review_score) AS avg_review,
           AVG(delivery_days) AS avg_delivery_days
    FROM v_item_facts
    WHERE order_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY seller_id, seller_state
    HAVING COUNT(DISTINCT order_id) >= 30
)
SELECT seller_id, seller_state, orders, ROUND(gmv,0) AS gmv,
       ROUND(100*late_rate,1) AS late_rate_pct, ROUND(avg_review,2) AS avg_review,
       ROUND(avg_delivery_days,1) AS avg_delivery_days,
       RANK() OVER (ORDER BY gmv DESC) AS gmv_rank,
       ROUND(100.0*SUM(gmv) OVER (ORDER BY gmv DESC) / SUM(gmv) OVER (), 1) AS cumulative_gmv_pct,
       NTILE(4) OVER (ORDER BY late_rate DESC) AS late_quartile   -- 1 = worst
FROM s ORDER BY gmv DESC;

-- name: q09_seller_pareto_all
-- Revenue concentration across ALL sellers (no minimum), decile view
WITH s AS (
    SELECT seller_id, SUM(price) AS gmv
    FROM v_item_facts WHERE order_month BETWEEN '2017-01' AND '2018-08' GROUP BY seller_id
), d AS (SELECT seller_id, gmv, NTILE(10) OVER (ORDER BY gmv DESC) AS decile FROM s)
SELECT decile, COUNT(*) AS sellers, ROUND(SUM(gmv),0) AS gmv,
       ROUND(100.0*SUM(gmv)/(SELECT SUM(gmv) FROM d),1) AS gmv_share_pct
FROM d GROUP BY decile ORDER BY decile;

-- name: q10_seller_state_late
SELECT seller_state, COUNT(DISTINCT order_id) AS orders,
       ROUND(100.0*AVG(is_late),1) AS late_rate_pct,
       ROUND(AVG(delivery_days),1) AS avg_delivery_days,
       ROUND(AVG(review_score),2) AS avg_review
FROM v_item_facts WHERE order_month BETWEEN '2017-01' AND '2018-08'
GROUP BY seller_state HAVING COUNT(DISTINCT order_id) >= 200
ORDER BY orders DESC;

-- name: q11_promise_accuracy
-- Is the problem slow delivery or an over-optimistic promise? Compare lateness by month.
SELECT order_month,
       ROUND(AVG(promised_days),1) AS avg_promised_days,
       ROUND(AVG(delivery_days),1) AS avg_actual_days,
       ROUND(100.0*AVG(is_late),2) AS late_rate_pct,
       ROUND(AVG(CASE WHEN is_late=1 THEN days_vs_promise END),1) AS avg_days_late_when_late
FROM v_order_facts
WHERE order_month BETWEEN '2017-01' AND '2018-08'
GROUP BY order_month ORDER BY order_month;
