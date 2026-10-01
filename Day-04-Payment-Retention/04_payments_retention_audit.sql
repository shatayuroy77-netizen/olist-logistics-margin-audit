-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 04 - Payment Approval Latency & Customer LTV
-- OBJECTIVE   : Diagnose bank clearance delays across payment methods (Boleto latency) 
--              and analyze cohort repurchase behavior to quantify customer churn.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 1: Payment Method Breakdown & Revenue Share
-- Question: Which payment channels drive the most transactions and revenue (GMV)?
-- Checking transaction volume, total value, average ticket size, and percentage share.
-- ----------------------------------------------------------------------------
SELECT 
    payment_type, 
    COUNT(order_id) AS no_of_transaction, 
    ROUND(SUM(payment_value), 2) AS total_transaction_value, 
    ROUND(AVG(payment_value), 2) AS avg_transaction_value, 
    ROUND(100.00 * SUM(payment_value) / SUM(SUM(payment_value)) OVER(), 2) AS gmv_share_pct
FROM order_payments
WHERE payment_type <> 'not_defined'
GROUP BY payment_type
ORDER BY total_transaction_value DESC;


-- ----------------------------------------------------------------------------
-- Step 2: Payment Approval Latency (Bank Clearance Delay)
-- Question: How long does each payment method take to clear and approve?
-- Measuring wait time in hours and days between order placement and payment approval.
-- ----------------------------------------------------------------------------
SELECT 
    op.payment_type,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,
                o.order_purchase_timestamp,
                o.order_approved_at) / 60.0),
            2) AS avg_approval_hours,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE,
                o.order_purchase_timestamp,
                o.order_approved_at) / 60.0) / 24.0,
            2) AS avg_approval_days
FROM orders o
INNER JOIN order_payments op 
    ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_approved_at IS NOT NULL
GROUP BY op.payment_type
ORDER BY avg_approval_hours DESC;


-- ----------------------------------------------------------------------------
-- Step 3: Credit Card Installment Depth
-- Question: Are customers using long-term installments for high-ticket orders?
-- Grouping installments into tiers to check transaction share vs ticket size.
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN payment_installments = 1 THEN '01_Lump_Sum (1x)'
        WHEN payment_installments BETWEEN 2 AND 3 THEN '02_Short_Tier (2-3x)'
        WHEN payment_installments BETWEEN 4 AND 6 THEN '03_Mid_Tier (4-6x)'
        ELSE '04_Long_Tier (7x+)'
    END AS installment_tier,
    COUNT(order_id) AS total_transaction,
    ROUND(SUM(payment_value), 2) AS total_gmv,
    ROUND(AVG(payment_value), 2) AS avg_ticket_value, 
    ROUND(100.00 * COUNT(order_id) / SUM(COUNT(order_id)) OVER(), 2) AS transaction_share_pct,
    ROUND(100.00 * SUM(payment_value) / SUM(SUM(payment_value)) OVER(), 2) AS gmv_share_pct
FROM order_payments 
WHERE payment_type = 'credit_card'
GROUP BY 1
ORDER BY 1;


-- ----------------------------------------------------------------------------
-- Step 4: Customer Order Frequency & Loyalty Baseline
-- Question: What percentage of buyers actually return for a second or third order?
-- Counting unique buyers by delivered order volume (1x, 2x, 3x+).
-- ----------------------------------------------------------------------------
SELECT
    CASE 
        WHEN total_orders = 1 THEN '01_Single_Purchase_Buyer (1x)'
        WHEN total_orders = 2 THEN '02_Repeat_Purchase_Buyer (2x)'
        ELSE '03_Loyal_Customer (3x+)'
    END AS customer_loyalty_segment,
    COUNT(customer_unique_id) AS total_unique_customer,
    ROUND(100.00 * COUNT(customer_unique_id) / SUM(COUNT(customer_unique_id)) OVER(), 2) AS customer_share_pct
FROM (
    SELECT 
        c.customer_unique_id, 
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM customers c 
    INNER JOIN orders o 
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
) AS customer_order_summary
GROUP BY customer_loyalty_segment
ORDER BY 2 DESC;


-- ----------------------------------------------------------------------------
-- Step 5: Cohort Revenue Contribution (AOV vs Lifetime Value)
-- Question: How much revenue comes from one-time buyers vs repeat customers?
-- Comparing total GMV share, average order value (AOV), and customer lifetime value (LTV).
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN cust.total_orders = 1 THEN '01_Single_Purchase_Buyer (1x)'
        WHEN cust.total_orders = 2 THEN '02_Repeat_Purchase_Buyer (2x)'
        ELSE '03_Loyal_Customer (3x+)'
    END AS customer_loyalty_segment,
    COUNT(cust.customer_unique_id) AS total_customers,
    ROUND(SUM(cust.total_spend), 2) AS total_gmv,
    ROUND(100.00 * SUM(cust.total_spend) / SUM(SUM(cust.total_spend)) OVER(), 2) AS gmv_share_pct,
    ROUND(SUM(cust.total_spend) / SUM(cust.total_orders), 2) AS avg_order_value_aov,
    ROUND(AVG(cust.total_spend), 2) AS avg_customer_lifetime_value
FROM (
    SELECT 
        c.customer_unique_id, 
        COUNT(DISTINCT o.order_id) AS total_orders,
        SUM(tovs.total_order_value) AS total_spend,
        ROUND(SUM(tovs.total_order_value) / COUNT(DISTINCT o.order_id), 2) AS customer_aov
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