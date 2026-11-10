-- =====================================================================
-- 01_views.sql  |  Olist: Delivery & Sales Performance Analysis
-- Builds reusable views. Dialect: SQLite (notes for MySQL/Postgres in README)
-- =====================================================================

DROP VIEW IF EXISTS v_order_value;
DROP VIEW IF EXISTS v_order_facts;
DROP VIEW IF EXISTS v_item_facts;

-- Order-level money: one row per order (items table has many rows per order)
CREATE VIEW v_order_value AS
SELECT order_id,
       COUNT(*)                         AS items,
       SUM(price)                       AS item_revenue,
       SUM(freight_value)               AS freight,
       SUM(price + freight_value)       AS order_total
FROM order_items
GROUP BY order_id;

-- One row per DELIVERED order with delivery KPIs, review score and customer keys.
-- Late = delivered after the estimated date promised at checkout.
-- Reviews: some orders have >1 review, so take the average to keep 1 row/order.
CREATE VIEW v_order_facts AS
WITH rev AS (
    SELECT order_id, AVG(review_score) AS review_score
    FROM order_reviews GROUP BY order_id
)
SELECT o.order_id,
       o.customer_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_purchase_timestamp                                   AS purchased_at,
       substr(o.order_purchase_timestamp, 1, 7)                     AS order_month,
       v.items, v.item_revenue, v.freight, v.order_total,
       julianday(o.order_delivered_customer_date)
         - julianday(o.order_purchase_timestamp)                    AS delivery_days,
       julianday(o.order_estimated_delivery_date)
         - julianday(o.order_purchase_timestamp)                    AS promised_days,
       julianday(o.order_delivered_customer_date)
         - julianday(o.order_estimated_delivery_date)               AS days_vs_promise, -- >0 = late
       CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1 ELSE 0 END                                       AS is_late,
       r.review_score
FROM orders o
JOIN customers c   ON c.customer_id = o.customer_id
JOIN v_order_value v ON v.order_id = o.order_id
LEFT JOIN rev r    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

-- One row per order ITEM, enriched with seller, English category and lateness.
CREATE VIEW v_item_facts AS
SELECT oi.order_id, oi.order_item_id, oi.seller_id, oi.product_id,
       oi.price, oi.freight_value,
       s.seller_state,
       COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       f.order_month, f.customer_state, f.delivery_days, f.is_late, f.review_score,
       f.customer_unique_id
FROM order_items oi
JOIN v_order_facts f ON f.order_id = oi.order_id
JOIN sellers s       ON s.seller_id = oi.seller_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name;
