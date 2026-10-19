-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 02 - Merchant SLA Compliance & Dispatch Breaches
-- OBJECTIVE   : Separate seller dispatch delays from carrier delays, measure
--               their effect on reviews, and segment sellers for targeted action.
-- PERIOD      : Jan-Jun 2018, delivered orders only. Counted per item.
-- DEFINITIONS : Breach = handed to carrier after shipping_limit_date.
--               Late   = delivered after the estimated date (date only, as in Day 1).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 1: Seller Dispatch Baseline
-- Question: How often did sellers miss their dispatch deadline in Q1 vs Q2?
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN o.order_purchase_timestamp >= '2018-01-01' AND o.order_purchase_timestamp < '2018-04-01' THEN '2018-Q1'
        WHEN o.order_purchase_timestamp >= '2018-04-01' AND o.order_purchase_timestamp < '2018-07-01' THEN '2018-Q2'
    END AS purchase_quarter,
    COUNT(oi.order_item_id) AS total_dispatched_items,
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
         AND DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
            THEN '01_clean_delivery'

        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
            THEN '02_carrier_rescue'

        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN '03_carrier_delay'

        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
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
-- Step 3: Top Offenders in Q2 by Customer Harm
-- Question: Which sellers caused the most late doorstep deliveries in Q2?
-- Ranked by direct customer delays, not breach count, because Step 7 shows
-- a breach alone does not hurt the review.
-- Filter: >= 20 items to remove random small noise.
-- ----------------------------------------------------------------------------
SELECT
    DENSE_RANK() OVER(ORDER BY SUM(CASE
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN 1
        ELSE 0
    END) DESC) AS harm_rank,
    oi.seller_id,
    COUNT(oi.order_item_id) AS total_items,
    SUM(CASE
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1
        ELSE 0
    END) AS breached_items,
    SUM(CASE
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
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
HAVING total_items >= 20
   AND direct_customer_delays > 0
ORDER BY direct_customer_delays DESC, breached_items DESC;


-- ----------------------------------------------------------------------------
-- Step 4: Q1 Historical Background Check
-- Question: Who were the worst dispatch breachers in Q1?
-- (Each Q2 offender's own Q1 record is in Step 5.)
-- ----------------------------------------------------------------------------
SELECT
    DENSE_RANK() OVER(ORDER BY (SUM(CASE WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1 ELSE 0 END)) DESC) AS breached_ranks,
    oi.seller_id,
    COUNT(oi.order_item_id) AS total_items,
    SUM(CASE
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date THEN 1
        ELSE 0
    END) AS breached_items,
    SUM(CASE
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
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
HAVING total_items >= 20
   AND breached_items > 0
ORDER BY breached_items DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- Step 5: Seller Performance, Q1 vs Q2
-- Question: How did each seller perform in Q1 compared to Q2?
-- Saved as a view so Steps 6, 8 and 10 can reuse it.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_seller_quarters AS
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
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN 1
        ELSE 0
    END) AS q2_direct_customer_delays
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY oi.seller_id;

SELECT *
FROM v_seller_quarters
WHERE (q1_total_items >= 20 AND q1_breaches > 0)
   OR (q2_total_items >= 20 AND q2_breaches > 0)
ORDER BY q2_breaches DESC;


-- ----------------------------------------------------------------------------
-- Step 6: Seller Segments
-- Question: Which sellers are chronic, which reformed, which got worse, and which left?
-- Breach limit: 10% of items (close to the Q1 platform average of 10.76%).
-- Sensitivity check: at 15%, chronic sellers drop from 25 to 15,
-- but their customer delays only drop from 75 to 68.
-- ----------------------------------------------------------------------------
SELECT
    seller_id,
    q1_total_items,
    q1_breaches,
    q2_total_items,
    q2_breaches,
    q2_direct_customer_delays,
    CASE
        WHEN q1_total_items >= 20 AND q2_total_items < 5 THEN 'exited'
        WHEN q1_total_items < 20 OR q2_total_items < 20 THEN 'not_enough_data'
        WHEN q1_breaches >= 0.10 * q1_total_items
         AND q2_breaches >= 0.10 * q2_total_items THEN 'chronic'
        WHEN q1_breaches >= 0.10 * q1_total_items THEN 'reformed'
        WHEN q2_breaches >= 0.10 * q2_total_items THEN 'got_worse'
        ELSE 'compliant'
    END AS seller_segment
FROM v_seller_quarters
WHERE (q1_total_items >= 20 AND q1_breaches > 0)
   OR (q2_total_items >= 20 AND q2_breaches > 0)
ORDER BY seller_segment, q2_breaches DESC;


-- ----------------------------------------------------------------------------
-- Step 7: Review Score by Fulfillment Bucket (Q2)
-- Question: Does a seller breach hurt the review, or only a late doorstep delivery?
-- Note: reviews are per order but counted per item, so multi-item orders weigh more.
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
            THEN '01_clean_delivery'
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
            THEN '02_carrier_rescue'
        WHEN o.order_delivered_carrier_date <= oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN '03_carrier_delay'
        WHEN o.order_delivered_carrier_date > oi.shipping_limit_date
         AND DATE(o.order_delivered_customer_date) > DATE(o.order_estimated_delivery_date)
            THEN '04_seller_delay'
        ELSE 'unclassified'
    END AS fulfillment_attribution,
    COUNT(oi.order_item_id) AS reviewed_items,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.00 * SUM(CASE WHEN r.review_score < 2 THEN 1 ELSE 0 END) / COUNT(oi.order_item_id), 2) AS one_star_pct
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN v_one_review r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-04-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
ORDER BY 1;


-- ----------------------------------------------------------------------------
-- Step 8: Review Score of High-Breach Sellers vs the Rest (Q2)
-- Question: Do customers of high-breach sellers give lower ratings?
-- Note: an order with items from two sellers shares one review between them.
-- ----------------------------------------------------------------------------
SELECT
    CASE
        WHEN v.q2_total_items < 20 THEN '03_small_seller'
        WHEN v.q2_breaches >= 0.10 * v.q2_total_items THEN '01_high_breach_seller'
        ELSE '02_normal_seller'
    END AS seller_group,
    COUNT(DISTINCT v.seller_id) AS sellers,
    COUNT(oi.order_item_id) AS reviewed_items,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.00 * SUM(CASE WHEN r.review_score < 2 THEN 1 ELSE 0 END) / COUNT(oi.order_item_id), 2) AS one_star_pct
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
INNER JOIN v_seller_quarters v ON oi.seller_id = v.seller_id
INNER JOIN v_one_review r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-04-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
ORDER BY 1;


-- ----------------------------------------------------------------------------
-- Step 9: Data Quality Check
-- Question: How many items show a carrier handover before the order was approved?
-- Result: 715 items (1.55%) show a carrier date before approval. All of them
-- were counted as on-time dispatches. Excluding them moves the breach rate
-- from 10.76% to 10.78% (Q1) and 6.43% to 6.63% (Q2), so they are kept.
-- ----------------------------------------------------------------------------
SELECT
    COUNT(oi.order_item_id) AS total_items,
    SUM(CASE WHEN o.order_delivered_carrier_date < o.order_approved_at THEN 1 ELSE 0 END) AS carrier_before_approval
FROM orders o
INNER JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01';


-- ----------------------------------------------------------------------------
-- Step 10: Action List for Vendor Operations
-- Question: Which sellers should be penalized now?
-- Rule: at least 20 items in Q2 and 3 or more late doorstep deliveries caused
-- by their own dispatch delay (repeated harm, not a one-off).
-- Result: 12 sellers, 95 of 220 seller-caused late deliveries (43%).
-- Only 7 of the 12 are 'chronic' in Step 6: 4 had too little Q1 history and
-- 1 counts as 'reformed' by breach rate but still hurt customers.
-- Impact: without these 95, seller-caused late items fall to 125 of 22,644 (0.55%).
-- About 38 fewer 1-star reviews a quarter: 95 x (48% - 8%), a rough estimate.
-- ----------------------------------------------------------------------------
SELECT
    seller_id,
    q2_total_items,
    q2_breaches,
    q2_direct_customer_delays
FROM v_seller_quarters
WHERE q2_total_items >= 20
  AND q2_direct_customer_delays >= 3
ORDER BY q2_direct_customer_delays DESC;