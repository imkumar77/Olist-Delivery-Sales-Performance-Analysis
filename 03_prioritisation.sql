-- =====================================================================
-- 03_prioritisation.sql | Where should operations act first?
-- "Excess late orders" = late orders above what the national late rate would predict.
-- =====================================================================

-- name: q12_state_priority
WITH nat AS (SELECT AVG(is_late) AS r FROM v_order_facts WHERE order_month BETWEEN '2017-01' AND '2018-08'),
s AS (
    SELECT customer_state AS state, COUNT(*) AS orders, SUM(is_late) AS late_orders,
           SUM(item_revenue) AS gmv, AVG(review_score) AS avg_review
    FROM v_order_facts WHERE order_month BETWEEN '2017-01' AND '2018-08' GROUP BY customer_state)
SELECT state, orders, late_orders,
       ROUND(100.0*late_orders/orders,1) AS late_rate_pct,
       ROUND(late_orders - orders*(SELECT r FROM nat), 0) AS excess_late_orders,
       ROUND(100.0*(late_orders - orders*(SELECT r FROM nat)) /
             SUM(MAX(late_orders - orders*(SELECT r FROM nat),0)) OVER (), 1) AS share_of_excess_pct,
       ROUND(gmv,0) AS gmv, ROUND(avg_review,2) AS avg_review
FROM s WHERE orders >= 100
ORDER BY excess_late_orders DESC;

-- name: q13_seller_priority
-- Sellers (min 100 orders) ranked by excess late orders vs national rate
WITH nat AS (SELECT AVG(is_late) AS r FROM v_order_facts WHERE order_month BETWEEN '2017-01' AND '2018-08'),
s AS (
    SELECT seller_id, seller_state, COUNT(DISTINCT order_id) AS orders,
           SUM(is_late) AS late_items, SUM(price) AS gmv,
           AVG(is_late) AS late_rate, AVG(review_score) AS avg_review, AVG(delivery_days) AS avg_days
    FROM v_item_facts WHERE order_month BETWEEN '2017-01' AND '2018-08'
    GROUP BY seller_id, seller_state HAVING COUNT(DISTINCT order_id) >= 100)
SELECT seller_id, seller_state, orders, ROUND(gmv,0) AS gmv,
       ROUND(100*late_rate,1) AS late_rate_pct, ROUND(avg_review,2) AS avg_review,
       ROUND(avg_days,1) AS avg_delivery_days,
       ROUND(orders*(late_rate - (SELECT r FROM nat)),0) AS excess_late_orders
FROM s WHERE late_rate > (SELECT r FROM nat)
ORDER BY excess_late_orders DESC;

-- name: q14_late_concentration
-- What share of ALL late orders comes from the worst 5 / 10 / 20 sellers, and from Nov-2017?
WITH late AS (
  SELECT seller_id, COUNT(DISTINCT order_id) AS late_orders
  FROM v_item_facts WHERE is_late=1 AND order_month BETWEEN '2017-01' AND '2018-08' GROUP BY seller_id),
r AS (SELECT seller_id, late_orders, RANK() OVER (ORDER BY late_orders DESC, seller_id) AS rk FROM late),
tot AS (SELECT COUNT(*) AS t FROM v_order_facts WHERE is_late=1 AND order_month BETWEEN '2017-01' AND '2018-08')
SELECT 'Top 5 sellers by late orders'  AS slice, SUM(late_orders) AS late_orders, ROUND(100.0*SUM(late_orders)/(SELECT t FROM tot),1) AS pct_of_all_late FROM r WHERE rk<=5
UNION ALL SELECT 'Top 10 sellers', SUM(late_orders), ROUND(100.0*SUM(late_orders)/(SELECT t FROM tot),1) FROM r WHERE rk<=10
UNION ALL SELECT 'Top 20 sellers', SUM(late_orders), ROUND(100.0*SUM(late_orders)/(SELECT t FROM tot),1) FROM r WHERE rk<=20
UNION ALL SELECT 'Nov-2017 (Black Friday month)', COUNT(DISTINCT order_id),
  ROUND(100.0*COUNT(DISTINCT order_id)/(SELECT t FROM tot),1) FROM v_item_facts WHERE is_late=1 AND order_month='2017-11';

-- name: q15_blackfriday_stress
-- Late rate in the weeks around Black Friday 2017 (24 Nov)
SELECT substr(purchased_at,1,10) AS day, COUNT(*) AS orders,
       ROUND(100.0*AVG(is_late),1) AS late_rate_pct, ROUND(AVG(delivery_days),1) AS avg_days
FROM v_order_facts
WHERE purchased_at BETWEEN '2017-11-15' AND '2017-12-05'
GROUP BY substr(purchased_at,1,10) ORDER BY day;

-- name: q16_late_by_category_priority
WITH nat AS (SELECT AVG(is_late) AS r FROM v_item_facts WHERE order_month BETWEEN '2017-01' AND '2018-08')
SELECT category, COUNT(DISTINCT order_id) AS orders, SUM(is_late) AS late_items,
       ROUND(100.0*AVG(is_late),1) AS late_rate_pct, ROUND(AVG(review_score),2) AS avg_review,
       ROUND(SUM(price),0) AS gmv
FROM v_item_facts WHERE order_month BETWEEN '2017-01' AND '2018-08'
GROUP BY category HAVING COUNT(DISTINCT order_id) >= 500
ORDER BY late_rate_pct DESC;

-- name: q17_cross_state_vs_local
-- Is distance the driver? Same-state vs cross-state deliveries
SELECT CASE WHEN seller_state = customer_state THEN 'Same state' ELSE 'Cross state' END AS route,
       COUNT(DISTINCT order_id) AS orders, ROUND(100.0*AVG(is_late),1) AS late_rate_pct,
       ROUND(AVG(delivery_days),1) AS avg_days, ROUND(AVG(freight_value),1) AS avg_freight,
       ROUND(AVG(review_score),2) AS avg_review
FROM v_item_facts WHERE order_month BETWEEN '2017-01' AND '2018-08'
GROUP BY route;
