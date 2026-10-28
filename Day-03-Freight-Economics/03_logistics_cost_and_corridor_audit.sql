-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 03 - Freight Charges & Interstate Corridors
-- OBJECTIVE   : Check whether freight charges are a cash risk: compare local and
--               interstate routes, find the costliest corridors and why, and
--               confirm who pays the freight.
-- PERIOD      : Jan-Jun 2018, delivered orders only. Counted per item
--               (Step 8 per order).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 1: Freight vs GMV by Quarter
-- Question: Is freight growing faster than GMV?
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(oi.order_item_id) AS total_items,
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
-- Step 2: Freight Higher Than Item Price (National)
-- Question: How often is freight equal to or higher than the item price?
-- Note: no item has freight exactly equal to price, so >= and > give the same count.
-- ----------------------------------------------------------------------------
SELECT 
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(oi.order_item_id) AS total_items,
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
-- Step 3: Local vs Interstate Split
-- Question: What share of items cross a state border?
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
-- Step 4: Freight Charge Gap, Local vs Interstate
-- Question: How much heavier is freight on interstate items?
-- Freight is also shown as % of item price, because interstate items cost more.
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
    COUNT(oi.order_item_id) AS total_items,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value,
    ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_gmv_pct
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
-- Step 5: Freight Higher Than Price, Local vs Interstate
-- Question: Is the freight-above-price problem mainly interstate?
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
    COUNT(oi.order_item_id) AS total_items,
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


-- ----------------------------------------------------------------------------
-- Step 6: Top 10 Interstate Corridors
-- Question: Which state-to-state routes carry the most freight?
-- Rule: at least 20 items per route, as in Day 2.
-- ----------------------------------------------------------------------------
SELECT 
    s.seller_state, c.customer_state,
    COUNT(oi.order_item_id) AS total_items,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value,
    ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_gmv_pct
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
  AND s.seller_state <> c.customer_state
GROUP BY s.seller_state, c.customer_state
HAVING COUNT(oi.order_item_id) >= 20
ORDER BY total_freight_value DESC LIMIT 10;


-- ----------------------------------------------------------------------------
-- Step 7: Local Purchase Share by Customer State
-- Question: How much of each state's buying comes from sellers in the same state?
-- ----------------------------------------------------------------------------
SELECT 
    c.customer_state,
    COUNT(oi.order_item_id) AS total_items,
    SUM(CASE WHEN s.seller_state = c.customer_state THEN 1 ELSE 0 END) AS local_items,
    ROUND(100.00 * SUM(CASE WHEN s.seller_state = c.customer_state THEN 1 ELSE 0 END) / COUNT(oi.order_item_id), 2) AS local_item_pct,
    ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_gmv_pct
FROM orders o
STRAIGHT_JOIN order_items oi ON o.order_id = oi.order_id
STRAIGHT_JOIN sellers s ON oi.seller_id = s.seller_id
STRAIGHT_JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY c.customer_state
ORDER BY local_item_pct, total_items DESC;


-- ----------------------------------------------------------------------------
-- Step 8: Who Pays the Freight?
-- Question: Does the customer pay the full freight?
-- Counted per order: items and payments are totalled per order before joining,
-- because both tables have several rows per order.
-- Result: 99.76% of orders match. The other 96 paid more, never less.
-- Note: 368 items (0.8%) had zero freight, likely free-shipping offers.
-- Who paid the carrier for these is not in the data.
-- ----------------------------------------------------------------------------
WITH item_totals AS (
    SELECT 
        oi.order_id,
        SUM(oi.price) AS items_price,
        SUM(oi.freight_value) AS items_freight
    FROM orders o
    INNER JOIN order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2018-01-01'
      AND o.order_purchase_timestamp <  '2018-07-01'
    GROUP BY oi.order_id
),
pay_totals AS (
    SELECT 
        order_id,
        SUM(payment_value) AS total_paid
    FROM order_payments
    GROUP BY order_id
)
SELECT 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN ABS(p.total_paid - (i.items_price + i.items_freight)) < 0.05 THEN 1 ELSE 0 END) AS matched_orders,
    ROUND(100.00 * SUM(CASE WHEN ABS(p.total_paid - (i.items_price + i.items_freight)) < 0.05 THEN 1 ELSE 0 END) / COUNT(*), 2) AS matched_pct,
    ROUND(SUM(i.items_price), 2) AS total_price,
    ROUND(SUM(i.items_freight), 2) AS total_freight,
    ROUND(SUM(p.total_paid), 2) AS total_paid
FROM item_totals i
INNER JOIN pay_totals p 
    ON i.order_id = p.order_id;