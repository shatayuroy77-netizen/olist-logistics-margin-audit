-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 03 - Freight Unit Economics & Toxic Freight Corridors
-- OBJECTIVE   : Diagnose logistics cost disparity between local and interstate 
--               shipping corridors, and quantify margin drag resulting from 
--               sub-economic toxic freight orders.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Macro Freight Burden vs GMV
-- Evaluating whether shipping cost inflation is outpacing GMV growth across quarters.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_gmv,
    ROUND(SUM(oi.freight_value), 2) AS total_freight,
    ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_gmv_pct
FROM orders o
INNER JOIN order_items oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- 2. National Toxic Freight Baseline
-- Measuring baseline volume and share of orders where delivery costs exceed item price.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    SUM(CASE
        WHEN oi.freight_value >= oi.price THEN 1
        ELSE 0
    END) AS toxic_freight_items,
    ROUND(100.00 * SUM(CASE
                WHEN oi.freight_value >= oi.price THEN 1
                ELSE 0
            END) / COUNT(oi.order_item_id), 2) AS toxic_item_pct
FROM orders o
INNER JOIN order_items oi 
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- 3. Fulfillment Corridor Split (Local vs Interstate)
-- Quantifying the volume share of long-haul shipments crossing state borders.
-- Note: STRAIGHT_JOIN used to drive from filtered 'orders' and prevent buffer pool exhaustion.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(oi.order_item_id) AS total_delivered_items,
    SUM(CASE WHEN s.seller_state <> c.customer_state THEN 1 ELSE 0 END) AS interstate_item_count,
    ROUND(100.00 * SUM(CASE WHEN s.seller_state <> c.customer_state THEN 1 ELSE 0 END) / COUNT(oi.order_item_id), 2) AS interstate_item_pct
FROM orders o
STRAIGHT_JOIN order_items oi ON o.order_id = oi.order_id
STRAIGHT_JOIN sellers s ON oi.seller_id = s.seller_id
STRAIGHT_JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
ORDER BY purchase_quarter;


-- ----------------------------------------------------------------------------
-- 4. Freight Cost Disparity Across Corridors
-- Comparing unit freight spend and total freight volume between local and interstate transit.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    CASE 
        WHEN s.seller_state <> c.customer_state THEN 'Interstate' 
        ELSE 'Local' 
    END AS shipping_type,
    COUNT(oi.order_item_id) AS total_order,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value
FROM orders o
STRAIGHT_JOIN order_items oi 
    ON o.order_id = oi.order_id
STRAIGHT_JOIN sellers s 
    ON oi.seller_id = s.seller_id
STRAIGHT_JOIN customers c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1, 2
ORDER BY purchase_quarter, shipping_type;


-- ----------------------------------------------------------------------------
-- 5. Toxic Freight Concentration by Corridor
-- Identifying margin leakage hotspots: evaluating toxic order share and subsidized freight by corridor.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    CASE 
        WHEN s.seller_state <> c.customer_state THEN 'Interstate' 
        ELSE 'Local' 
    END AS shipping_type,
    COUNT(oi.order_item_id) AS total_order,
    SUM(CASE WHEN oi.freight_value >= oi.price THEN 1 ELSE 0 END) AS toxic_item,
    ROUND(100.00 * SUM(CASE WHEN oi.freight_value >= oi.price THEN 1 ELSE 0 END) / COUNT(oi.order_item_id), 2) AS toxic_item_pct,
    ROUND(SUM(CASE WHEN oi.freight_value >= oi.price THEN oi.freight_value ELSE 0 END), 2) AS total_toxic_freight_value,
    ROUND(AVG(CASE WHEN oi.freight_value >= oi.price THEN oi.freight_value ELSE NULL END), 2) AS avg_toxic_freight
FROM orders o
STRAIGHT_JOIN order_items oi 
    ON o.order_id = oi.order_id
STRAIGHT_JOIN sellers s 
    ON oi.seller_id = s.seller_id
STRAIGHT_JOIN customers c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1, 2
ORDER BY purchase_quarter, shipping_type;