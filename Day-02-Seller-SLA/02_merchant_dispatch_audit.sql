-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 02 - Merchant SLA Compliance & Dispatch Breaches
-- OBJECTIVE   : Build a 4-bucket fulfillment classification matrix to isolate 
--               seller dispatch delays from carrier rescue transit, and rank 
--               the Top 10 chronic offender merchants.				 
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 1: Merchant Dispatch Baseline
-- Measuring baseline seller dispatch breach rates across Q1 and Q2.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(oi.order_item_id) AS total_dispatched_orders,
    SUM(CASE
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date THEN 1
        ELSE 0
    END) AS on_time_dispatches,
    SUM(CASE
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1
        ELSE 0
    END) AS breached_dispatches,
    ROUND(100.00 * SUM(CASE
                WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1
                ELSE 0
            END) / COUNT(oi.order_item_id), 2) AS dispatch_breach_pct
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY purchase_quarter
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- Step 2: 4-Bucket Fulfillment Matrix
-- Question: Does a seller dispatch breach always cause a late doorstep delivery?
-- Checking how many seller delays are actually absorbed/rescued by courier transit.
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
         AND o.order_delivered_customer_date <= o.order_estimated_delivery_date
            THEN '01_clean_delivery'
            
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND o.order_delivered_customer_date <= o.order_estimated_delivery_date 
            THEN '02_carrier_rescue'
            
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN '03_carrier_delay'
            
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN '04_seller_delay'
            
        ELSE 'unclassified'
    END AS fulfillment_attribution,
    COUNT(oi.order_item_id) AS total_items,
    ROUND(
        100.00 * COUNT(oi.order_item_id) / SUM(COUNT(oi.order_item_id)) OVER(), 
        2
    ) AS pct_of_total
FROM orders o 
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-04-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
ORDER BY 1;


-- ----------------------------------------------------------------------------
-- Step 3: Top Chronic Offenders in Q2
-- Question: Who are the top offenders by breached volume, and did their lag hurt the customer?
-- Filter: >= 20 items to remove random small noise.
-- ----------------------------------------------------------------------------
SELECT 
    DENSE_RANK() OVER(ORDER BY (SUM(CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END)) DESC) AS breached_ranks,
    oi.seller_id, 
    COUNT(oi.order_item_id) AS total_item,
    SUM(CASE 
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 
        ELSE 0 
    END) AS breached_items,
    SUM(CASE 
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date 
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 
        ELSE 0 
    END) AS direct_customer_delays,
    ROUND(
        100.00 * SUM(CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END)
        / COUNT(oi.order_item_id), 
        2
    ) AS breach_items_pct
FROM orders o 
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-04-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY oi.seller_id
HAVING total_item >= 20
   AND breached_items > 0
ORDER BY breached_items DESC;


-- ----------------------------------------------------------------------------
-- Step 4: Q1 Historical Background Check
-- Question: Did these Q2 offenders have a track record of delay in Q1 as well?
-- Checking Jan-Mar 2018 to see baseline repeat behavior.
-- ----------------------------------------------------------------------------
SELECT 
    DENSE_RANK() OVER(ORDER BY (SUM(CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END)) DESC) AS breached_ranks,
    oi.seller_id, 
    COUNT(oi.order_item_id) AS total_item,
    SUM(CASE 
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 
        ELSE 0 
    END) AS breached_items,
    SUM(CASE 
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date 
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 
        ELSE 0 
    END) AS direct_customer_delays,
    ROUND(
        100.00 * SUM(CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END)
        / COUNT(oi.order_item_id), 
        2
    ) AS breach_items_pct
FROM orders o 
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-04-01'
GROUP BY oi.seller_id
HAVING total_item >= 20
   AND breached_items > 0
ORDER BY breached_items DESC;


-- ----------------------------------------------------------------------------
-- Step 5: Side-by-Side Pivot (Q1 vs Q2 Longitudinal Audit)
-- Question: Mapping both quarters side-by-side to profile actionable merchant groups:
-- 1. Chronic offenders (bad in both quarters)
-- 2. Scaling breakdown (failed only when volume grew)
-- 3. Reformed merchants (fixed dispatch issues in Q2)
-- ----------------------------------------------------------------------------
SELECT 
    oi.seller_id,
    SUM(CASE
        WHEN o.order_purchase_timestamp < '2018-04-01' THEN 1
        ELSE 0
    END) AS q1_total_items,
    SUM(CASE
        WHEN o.order_purchase_timestamp < '2018-04-01'
         AND o.order_delivered_carrier_date > oi.shipping_limit_date
            THEN 1
        ELSE 0
    END) AS q1_breaches,
    SUM(CASE
        WHEN o.order_purchase_timestamp >= '2018-04-01' THEN 1
        ELSE 0
    END) AS q2_total_items,
    SUM(CASE
        WHEN o.order_purchase_timestamp >= '2018-04-01'
         AND o.order_delivered_carrier_date > oi.shipping_limit_date
            THEN 1
        ELSE 0
    END) AS q2_breaches,
    SUM(CASE
        WHEN o.order_purchase_timestamp >= '2018-04-01'
         AND o.order_delivered_carrier_date > oi.shipping_limit_date
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 1
        ELSE 0
    END) AS q2_direct_customer_delays
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY oi.seller_id
HAVING q2_total_items >= 20 AND q2_breaches > 0
ORDER BY q2_breaches DESC;