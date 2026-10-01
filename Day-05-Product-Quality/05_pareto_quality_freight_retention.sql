-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 05 - Pareto Revenue Segmentation & Quality Control
-- OBJECTIVE   : Execute ABC/Pareto 80/20 category revenue classification and 
--              correlate product volumetric density against logistics delays 
--              and negative customer reviews.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 0: Base Delivered Items View
-- Flat clean view for delivered items with English category names to skip 
-- joining orders, items, products, and translations repeatedly downstream.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_clean_delivered_items AS
WITH filtered_item AS (
    SELECT 
        oi.price, 
        oi.order_id, 
        oi.order_item_id,
        oi.product_id
    FROM orders o 
    INNER JOIN order_items oi 
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
), 
product_info AS (
    SELECT 
        fi.price, 
        fi.order_id, 
        fi.order_item_id,
        fi.product_id, 
        p.product_category_name
    FROM filtered_item fi 
    INNER JOIN products p 
        ON p.product_id = fi.product_id
),
pdt_trns AS (
    SELECT 
        pi.price, 
        pi.order_id, 
        pi.order_item_id,
        pi.product_id, 
        COALESCE(ct.product_category_name_english, pi.product_category_name, 'unlabeled') AS category_name
    FROM product_info pi 
    LEFT JOIN category_translation ct 
        ON ct.product_category_name = pi.product_category_name
)
SELECT 
    order_id, 
    order_item_id, 
    product_id, 
    price, 
    category_name
FROM pdt_trns;


-- ----------------------------------------------------------------------------
-- Step 1A: Pareto & Cumulative GMV Distribution
-- Checking 80/20 revenue concentration across categories.
-- Using window sums to track cumulative share and ranking by GMV.
-- ----------------------------------------------------------------------------
SELECT 
    DENSE_RANK() OVER (ORDER BY SUM(price) DESC) AS revenue_rank,
    category_name, 
    COUNT(order_item_id) AS total_item_sold,
    ROUND(SUM(price), 2) AS total_GMV,
    ROUND(AVG(price), 2) AS avg_item_price,
    ROUND(100.00 * SUM(price) / SUM(SUM(price)) OVER (), 2) AS GMV_share_pct,
    ROUND(100.00 * SUM(SUM(price)) OVER (ORDER BY SUM(price) DESC) / SUM(SUM(price)) OVER (), 2) AS cumulative_top_GMV_Share_pct
FROM v_clean_delivered_items
GROUP BY category_name
ORDER BY total_GMV DESC;


-- ----------------------------------------------------------------------------
-- Step 1B: ABC Revenue Segmentation
-- Segmenting categories into Class A (top 70%), Class B (next 20%), Class C (tail 10%).
-- Measuring catalog dependency and long-tail category volume.
-- ----------------------------------------------------------------------------
WITH category_metrics AS (
    SELECT 
        category_name, 
        ROUND(SUM(price), 2) AS total_GMV,
        ROUND(100.00 * SUM(SUM(price)) OVER (ORDER BY SUM(price) DESC) / SUM(SUM(price)) OVER (), 2) AS cumulative_GMV_Share_pct
    FROM v_clean_delivered_items
    GROUP BY category_name
),
categorized_data AS (
    SELECT 
        category_name, 
        total_GMV,
        CASE 
            WHEN cumulative_GMV_Share_pct <= 70.00 THEN 'Class A (Top 70%)'
            WHEN cumulative_GMV_Share_pct <= 90.00 THEN 'Class B (Next 20%)'
            ELSE 'Class C (Tail 10%)'
        END AS abc_tier
    FROM category_metrics
)
SELECT 
    abc_tier,
    COUNT(category_name) AS total_categories,
    ROUND(SUM(total_GMV), 2) AS tier_gmv,
    ROUND(100.00 * SUM(total_GMV) / (SELECT SUM(total_GMV) FROM categorized_data), 2) AS tier_share_pct
FROM categorized_data
GROUP BY abc_tier
ORDER BY tier_gmv DESC;


-- ----------------------------------------------------------------------------
-- Step 2: Quality Issues vs Logistics Delays
-- Isolating product/seller defects from shipping delays.
-- Filter: on-time or early deliveries only (actual <= estimated).
-- Threshold: categories with >= 100 reviews to eliminate low-sample noise.
-- ----------------------------------------------------------------------------
SELECT 
    v.category_name, 
    COUNT(DISTINCT o_r.review_id) AS total_review, 
    ROUND(AVG(o_r.review_score), 2) AS avg_review,
    SUM(CASE WHEN o_r.review_score = 1 THEN 1 ELSE 0 END) AS one_star_count,
    ROUND(100.00 * SUM(CASE WHEN o_r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(o_r.review_score), 2) AS one_star_rate_pct
FROM v_clean_delivered_items v 
INNER JOIN order_reviews o_r 
    ON v.order_id = o_r.order_id
INNER JOIN orders o 
    ON o.order_id = o_r.order_id
WHERE o.order_delivered_customer_date <= o.order_estimated_delivery_date
GROUP BY v.category_name
HAVING total_review >= 100
ORDER BY one_star_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- Step 3: Freight Burden & Volumetric Weight
-- Checking shipping cost to item price ratio along with weight and volume.
-- Spotting categories where delivery costs risk cart drop-offs.
-- Threshold: >= 100 items sold.
-- ----------------------------------------------------------------------------
SELECT 
    COALESCE(ct.product_category_name_english, p.product_category_name, 'unlabeled') AS category_name,
    COUNT(oi.order_item_id) AS total_items_sold,
    ROUND(SUM(oi.price), 2) AS total_price,
    ROUND(SUM(oi.freight_value), 2) AS total_freight_value,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight_value,
    ROUND(AVG(p.product_weight_g) / 1000.0, 2) AS avg_weight_kg,
    ROUND(AVG(p.product_length_cm * p.product_height_cm * p.product_width_cm) / 1000.0, 2) AS avg_vol_liters,
    ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_price_ratio_pct
FROM orders o
INNER JOIN order_items oi 
    ON o.order_id = oi.order_id
INNER JOIN products p 
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct 
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY 1
HAVING total_items_sold >= 100
ORDER BY freight_to_price_ratio_pct DESC;


-- ----------------------------------------------------------------------------
-- Step 4: Repeat Buyers vs One-and-Done Categories
-- Mapping repeat customers (2+ delivered orders) back to product categories.
-- Identifies organic repeat drivers vs one-off purchase categories.
-- Threshold: >= 200 orders for statistical reliability.
-- ----------------------------------------------------------------------------
WITH repeat_buyers AS (
    SELECT 
        c.customer_unique_id
    FROM orders o 
    INNER JOIN customers c 
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
)
SELECT 
    v.category_name, 
    COUNT(DISTINCT v.order_id) AS total_orders,
    COUNT(DISTINCT CASE WHEN rb.customer_unique_id IS NOT NULL THEN v.order_id END) AS repeat_orders_count,
    COUNT(DISTINCT CASE WHEN rb.customer_unique_id IS NULL THEN v.order_id END) AS one_time_orders_count,
    ROUND(100.00 * COUNT(DISTINCT CASE WHEN rb.customer_unique_id IS NOT NULL THEN v.order_id END) / COUNT(DISTINCT v.order_id), 2) AS repeat_order_share_pct
FROM v_clean_delivered_items v 
INNER JOIN orders o 
    ON v.order_id = o.order_id
INNER JOIN customers c 
    ON c.customer_id = o.customer_id
LEFT JOIN repeat_buyers rb 
    ON rb.customer_unique_id = c.customer_unique_id
GROUP BY v.category_name
HAVING total_orders >= 200
ORDER BY repeat_order_share_pct DESC;