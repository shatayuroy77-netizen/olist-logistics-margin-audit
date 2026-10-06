-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 01 - Macro Fulfillment Baseline & Delivery Bottlenecks
-- OBJECTIVE   : Establish delivery SLA baselines, quantify fulfillment delays, 
--               and evaluate customer review sentiment against carrier transit lags
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 0: Database & Schema Preparation
-- Goal: Ensure timestamp columns are properly typed for date operations.
-- Note: run once before the analysis queries.
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS olist_db;
USE olist_db;

ALTER TABLE orders
    MODIFY COLUMN order_purchase_timestamp DATETIME,
    MODIFY COLUMN order_approved_at DATETIME,
    MODIFY COLUMN order_delivered_carrier_date DATETIME,
    MODIFY COLUMN order_estimated_delivery_date DATETIME,
    MODIFY COLUMN order_delivered_customer_date DATETIME;


-- Reusable view: one review score per order (some orders have multiple reviews)
CREATE OR REPLACE VIEW v_one_review AS
SELECT order_id, AVG(review_score) AS review_score
FROM order_reviews
GROUP BY order_id;


-- ----------------------------------------------------------------------------
-- Step 1: Macro Fulfillment Baseline
-- Question: Did national late delivery rates worsen in 2018-Q2 compared to Q1?
-- Measuring baseline delivered volume and percentage of doorstep delivery breaches.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN order_purchase_timestamp >= '2018-01-01' AND order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN order_purchase_timestamp >= '2018-04-01' AND order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(order_id) AS total_delivered_orders,
    ROUND(100.0 * SUM(CASE
                WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date) THEN 1
                ELSE 0
            END) / COUNT(order_id), 2) AS late_order_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND order_purchase_timestamp >= '2018-01-01'
  AND order_purchase_timestamp < '2018-07-01'
GROUP BY purchase_quarter
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- Step 2a: Process Bottleneck Identification
-- Question: Is the delivery delay driven by seller dispatch lag or courier transit lag?
-- Deconstructing fulfillment duration into merchant dispatch vs courier transit.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN order_purchase_timestamp >= '2018-01-01' AND order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN order_purchase_timestamp >= '2018-04-01' AND order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(order_id) AS total_delivered_orders,
    ROUND(AVG(DATEDIFF(order_delivered_carrier_date, order_approved_at)), 2) AS avg_seller_days,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_delivered_carrier_date)), 2) AS avg_carrier_days
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND DATEDIFF(order_delivered_carrier_date, order_approved_at) >= 0
  AND order_purchase_timestamp >= '2018-01-01'
  AND order_purchase_timestamp < '2018-07-01'
GROUP BY purchase_quarter
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- Step 2b: Late vs On-Time Bottleneck Comparison
-- Question: Do late orders lose their time at the seller stage or the carrier stage?
-- Comparing seller dispatch days and carrier transit days for late vs on-time orders.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN order_purchase_timestamp >= '2018-01-01' AND order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN order_purchase_timestamp >= '2018-04-01' AND order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    CASE
        WHEN DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date) THEN 'delay'
        ELSE 'on time'
    END AS delivery_status,
    COUNT(order_id) AS total_delivered_orders,
    ROUND(AVG(DATEDIFF(order_delivered_carrier_date, order_approved_at)), 2) AS avg_seller_days,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_delivered_carrier_date)), 2) AS avg_carrier_days
FROM orders
WHERE order_status = 'delivered'
  AND order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND DATEDIFF(order_delivered_carrier_date, order_approved_at) >= 0
  AND order_purchase_timestamp >= '2018-01-01'
  AND order_purchase_timestamp < '2018-07-01'
GROUP BY purchase_quarter, delivery_status
ORDER BY purchase_quarter, delivery_status;


-- ----------------------------------------------------------------------------
-- Step 3: Customer Sentiment vs Delivery Punctuality
-- Question: How severe is the customer review score penalty when a delivery is delayed?
-- Quantifying the impact of on-time vs delayed deliveries on average review scores.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    CASE
        WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date) THEN 'delay'
        ELSE 'on time'
    END AS delivery_status,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o_r.review_score), 2) AS avg_review_score
FROM orders o
INNER JOIN v_one_review o_r ON o.order_id = o_r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp < '2018-07-01'
GROUP BY purchase_quarter, delivery_status
ORDER BY purchase_quarter, delivery_status;


-- ----------------------------------------------------------------------------
-- Step 4: Regional Performance Validation
-- Question: Did remote states face isolated logistics failures masked by São Paulo volume?
-- Auditing state-level delay rates and review score distributions across quarters.
-- ----------------------------------------------------------------------------
SELECT 
    c.customer_state,
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    ROUND(100.0 * SUM(CASE
                WHEN DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date) THEN 1
                ELSE 0
            END) / COUNT(o.order_id), 2) AS late_order_pct,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o_r.review_score), 2) AS avg_review_score
FROM orders o
INNER JOIN v_one_review o_r ON o.order_id = o_r.order_id
INNER JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp < '2018-07-01'
GROUP BY c.customer_state, purchase_quarter
ORDER BY c.customer_state, purchase_quarter;


-- ----------------------------------------------------------------------------
-- Step 5a: The Survivorship Bias Audit
-- Question: Are non-delivered orders (cancelled, unavailable, stuck in transit) dragging down the overall review score?
-- Checking non-delivered order status distributions and their impact on review sentiment.
-- ----------------------------------------------------------------------------
SELECT 
    o.order_status,
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(o_r.review_score), 2) AS avg_review_score
FROM orders o
LEFT JOIN v_one_review o_r ON o.order_id = o_r.order_id
WHERE o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp < '2018-07-01'
GROUP BY purchase_quarter, o.order_status
ORDER BY purchase_quarter, total_orders DESC;


-- ----------------------------------------------------------------------------
-- Step 5b: Measuring the Non-Delivered Drag
-- Question: By how much do non-delivered orders pull down the overall review score?
-- Comparing the average score of all reviewed orders vs delivered orders only.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(o_r.review_score) AS reviewed_orders,
    ROUND(AVG(o_r.review_score), 2) AS avg_score_all_orders,
    ROUND(AVG(CASE WHEN o.order_status = 'delivered' THEN o_r.review_score END), 2) AS avg_score_delivered_only,
    ROUND(AVG(o_r.review_score) - AVG(CASE WHEN o.order_status = 'delivered' THEN o_r.review_score END), 2) AS score_drag
FROM orders o
LEFT JOIN v_one_review o_r ON o.order_id = o_r.order_id
WHERE o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp < '2018-07-01'
GROUP BY purchase_quarter
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- Step 6: The Reporting Lag Test (Review Intake Date)
-- Question: Does review sentiment change if evaluated by survey creation date instead of purchase date?
-- Isolating operational lag by evaluating quarterly review intake directly.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN review_creation_date >= '2018-01-01' AND review_creation_date < '2018-04-01' THEN '2018-Q1'
        WHEN review_creation_date >= '2018-04-01' AND review_creation_date < '2018-07-01' THEN '2018-Q2'
    END AS review_quarter,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score
FROM order_reviews
WHERE review_creation_date >= '2018-01-01'
  AND review_creation_date < '2018-07-01'
GROUP BY review_quarter
ORDER BY review_quarter;


-- ----------------------------------------------------------------------------
-- Step 7: Month-over-Month Granularity & 1-Star Complaint Spike
-- Question: When exactly did the customer complaint spike occur, and how deep was the 1-star surge?
-- Breaking down monthly review intake, average scores, and 1-star negative review percentage.
-- ----------------------------------------------------------------------------
SELECT 
    LEFT(review_creation_date, 7) AS review_month,
    COUNT(*) AS total_reviews,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    SUM(CASE
        WHEN review_score = 1 THEN 1
        ELSE 0
    END) AS one_star_reviews,
    ROUND(100.0 * SUM(CASE
                WHEN review_score = 1 THEN 1
                ELSE 0
            END) / COUNT(*), 2) AS one_star_pct
FROM order_reviews
WHERE review_creation_date >= '2018-01-01'
  AND review_creation_date < '2018-07-01'
GROUP BY review_month
ORDER BY review_month;