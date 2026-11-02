-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 04 - Payment Speed & Repeat Customers
-- OBJECTIVE   : Check Lucas's claims on Boleto speed and repeat buying,
--               and whether slow Boleto is why customers don't come back.
-- PERIOD      : Steps 1-3: Jan-Jun 2018, per order. Steps 4-6: full
--               history, per customer. Delivered only, except Step 3.
-- SETUP       : Run Day 3, Step 0 first. It creates the indexes these joins
--               need; without them Step 6 never finished.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 1: Payment Methods by Orders and Money
-- Question: How big is Boleto compared to the other methods?
-- Note: payment_value includes freight, unlike Day 3 GMV.
-- ----------------------------------------------------------------------------
SELECT 
    op.payment_type, 
    COUNT(DISTINCT op.order_id) AS total_orders, 
    ROUND(SUM(op.payment_value), 2) AS total_paid, 
    ROUND(SUM(op.payment_value) / COUNT(DISTINCT op.order_id), 2) AS avg_paid_per_order, 
    ROUND(100.00 * SUM(op.payment_value) / SUM(SUM(op.payment_value)) OVER(), 2) AS paid_share_pct
FROM orders o
INNER JOIN order_payments op 
    ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
  AND op.payment_type <> 'not_defined'
GROUP BY op.payment_type
ORDER BY total_paid DESC;


-- ----------------------------------------------------------------------------
-- Step 2: Approval Time by Payment Method
-- Question: Does Boleto really take more than a day to get approved?
-- Rule: one row per order and payment type before the join.
-- ----------------------------------------------------------------------------
SELECT 
    op.payment_type,
    COUNT(o.order_id) AS total_orders,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,
                o.order_purchase_timestamp,
                o.order_approved_at) / 60.0),
            2) AS avg_approval_hours,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,
                o.order_purchase_timestamp,
                o.order_approved_at) / 60.0) / 24.0,
            2) AS avg_approval_days,
    ROUND(100.00 * SUM(CASE
                WHEN TIMESTAMPDIFF(MINUTE,
                        o.order_purchase_timestamp,
                        o.order_approved_at) > 1440 THEN 1
                ELSE 0
            END) / COUNT(o.order_id), 2) AS over_24h_pct
FROM orders o
INNER JOIN (
    SELECT DISTINCT order_id, payment_type
    FROM order_payments
) AS op 
    ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
  AND o.order_approved_at IS NOT NULL
GROUP BY op.payment_type
ORDER BY avg_approval_hours DESC;


-- ----------------------------------------------------------------------------
-- Step 3: Orders Lost by Payment Method
-- Question: Do we lose more Boleto orders?
-- Rule: lost = canceled or unavailable.
-- ----------------------------------------------------------------------------
SELECT 
    op.payment_type,
    COUNT(o.order_id) AS total_orders,
    SUM(CASE
        WHEN o.order_status IN ('canceled', 'unavailable') THEN 1
        ELSE 0
    END) AS lost_orders,
    ROUND(100.00 * SUM(CASE
                WHEN o.order_status IN ('canceled', 'unavailable') THEN 1
                ELSE 0
            END) / COUNT(o.order_id), 2) AS lost_pct
FROM orders o
INNER JOIN (
    SELECT DISTINCT order_id, payment_type
    FROM order_payments
) AS op 
    ON o.order_id = op.order_id
WHERE o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
  AND op.payment_type <> 'not_defined'
GROUP BY op.payment_type
ORDER BY total_orders DESC;


-- ----------------------------------------------------------------------------
-- Step 4: How Many Customers Come Back
-- Question: What share of customers buy a second time?
-- Rule: counted by customer_unique_id, not customer_id.
-- ----------------------------------------------------------------------------
SELECT
    CASE 
        WHEN total_orders = 1 THEN '01_Single_Purchase_Buyer (1x)'
        WHEN total_orders = 2 THEN '02_Repeat_Purchase_Buyer (2x)'
        ELSE '03_Loyal_Customer (3x+)'
    END AS customer_loyalty_segment,
    COUNT(customer_unique_id) AS total_unique_customers,
    ROUND(100.00 * COUNT(customer_unique_id) / SUM(COUNT(customer_unique_id)) OVER(), 2) AS customer_share_pct
FROM (
    SELECT 
        c.customer_unique_id, 
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c 
    INNER JOIN orders o 
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) AS customer_order_summary
GROUP BY customer_loyalty_segment
ORDER BY customer_loyalty_segment;


-- ----------------------------------------------------------------------------
-- Step 5: Money from One-Time vs Repeat Customers
-- Question: How much of our money comes from one-time buyers?
-- Note: Step 4 has 90,557 single buyers, this step has 90,556.
--       One delivered order has no payment row, so the INNER JOIN
--       drops that buyer.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN cust.total_orders = 1 THEN '01_Single_Purchase_Buyer (1x)'
        WHEN cust.total_orders = 2 THEN '02_Repeat_Purchase_Buyer (2x)'
        ELSE '03_Loyal_Customer (3x+)'
    END AS customer_loyalty_segment,
    COUNT(cust.customer_unique_id) AS total_customers,
    ROUND(SUM(cust.total_spend), 2) AS total_paid,
    ROUND(100.00 * SUM(cust.total_spend) / SUM(SUM(cust.total_spend)) OVER(), 2) AS paid_share_pct,
    ROUND(SUM(cust.total_spend) / SUM(cust.total_orders), 2) AS avg_paid_per_order,
    ROUND(AVG(cust.total_spend), 2) AS avg_paid_per_customer
FROM (
    SELECT 
        c.customer_unique_id, 
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(tovs.total_order_value) AS total_spend
    FROM (
        SELECT 
            order_id, 
            SUM(payment_value) AS total_order_value
        FROM order_payments
        GROUP BY order_id
    ) AS tovs 
    INNER JOIN orders o 
        ON o.order_id = tovs.order_id
    INNER JOIN customers c 
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
) AS cust
GROUP BY customer_loyalty_segment
ORDER BY customer_loyalty_segment;


-- ----------------------------------------------------------------------------
-- Step 6: Repeat Buying by First Payment Method
-- Question: Do customers who paid by Boleto the first time come back less?
-- Note: first delivered order only; mixed payments take the biggest method.
-- Note: split into two indexed temp tables. Run all three parts in one
--       session, as temp tables disappear when the connection closes.
-- ----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS tmp_customer_orders;
CREATE TEMPORARY TABLE tmp_customer_orders AS
SELECT 
    c.customer_unique_id,
    o.order_id,
    ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                       ORDER BY o.order_purchase_timestamp) AS order_no,
    COUNT(*) OVER (PARTITION BY c.customer_unique_id) AS total_orders
FROM orders o
INNER JOIN customers c 
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered';
CREATE INDEX idx_tco_order_id ON tmp_customer_orders (order_id(32));

DROP TEMPORARY TABLE IF EXISTS tmp_main_payment;
CREATE TEMPORARY TABLE tmp_main_payment AS
SELECT 
    order_id,
    payment_type,
    ROW_NUMBER() OVER (PARTITION BY order_id
                       ORDER BY payment_value DESC) AS pay_no
FROM order_payments;
CREATE INDEX idx_tmp_order_id ON tmp_main_payment (order_id(32));

SELECT 
    mp.payment_type AS first_order_payment,
    COUNT(*) AS total_customers,
    SUM(CASE
        WHEN co.total_orders > 1 THEN 1
        ELSE 0
    END) AS came_back,
    ROUND(100.00 * SUM(CASE
                WHEN co.total_orders > 1 THEN 1
                ELSE 0
            END) / COUNT(*), 2) AS came_back_pct
FROM tmp_customer_orders co
INNER JOIN tmp_main_payment mp 
    ON mp.order_id = co.order_id
   AND mp.pay_no = 1
WHERE co.order_no = 1
GROUP BY mp.payment_type
ORDER BY total_customers DESC;