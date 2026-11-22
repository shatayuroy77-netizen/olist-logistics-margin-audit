-- ============================================================================
-- PROJECT     : Olist E-Commerce Logistics & Margin Audit
-- AUTHOR      : Shatayu Roy
-- MODULE      : Day 05 - Category Value & Repeat Buying
-- OBJECTIVE   : Check Marcelo's claim that Electronics and Office Furniture
--               are high-ticket, and whether their buyers come back.
-- PERIOD      : Steps 1, 3, 4: Jan-Jun 2018, delivered only. Steps 2 and 2b:
--               full history, per customer, same as Day 4. Step 5 combines both.
-- SETUP       : Run Day 3, Step 0 first (indexes).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Step 0: Base Delivered Items View
-- Flat clean view for delivered items with English category names to skip 
-- joining orders, items, products, and translations repeatedly downstream.
-- Note: Jan-Jun 2018 only. Step 2 does not use this view (needs full history).
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
      AND o.order_purchase_timestamp >= '2018-01-01'
      AND o.order_purchase_timestamp <  '2018-07-01'
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
-- Step 1: Category Sales and Average Price
-- Question: Are Electronics and Office Furniture really high-ticket categories?
-- Note: overall_avg_item_price = total GMV / total items, not an average of averages.
-- ----------------------------------------------------------------------------
SELECT 
    DENSE_RANK() OVER (ORDER BY SUM(price) DESC) AS revenue_rank,
    category_name, 
    COUNT(order_item_id) AS total_item_sold,
    ROUND(SUM(price), 2) AS total_GMV,
    ROUND(AVG(price), 2) AS avg_item_price,
    ROUND(SUM(SUM(price)) OVER () / SUM(COUNT(order_item_id)) OVER (), 2) AS overall_avg_item_price,
    ROUND(100.00 * SUM(price) / SUM(SUM(price)) OVER (), 2) AS GMV_share_pct,
    ROUND(100.00 * SUM(SUM(price)) OVER (ORDER BY SUM(price) DESC) / SUM(SUM(price)) OVER (), 2) AS cumulative_top_GMV_Share_pct
FROM v_clean_delivered_items
GROUP BY category_name
ORDER BY total_GMV DESC;


-- ----------------------------------------------------------------------------
-- Step 2: Repeat Buying by First-Order Category
-- Question: Do customers whose first order was Electronics or Office
--           Furniture come back less than others?
-- Note: full history, per customer, same as Day 4 Step 6. A first order
--       with mixed categories takes the category of its priciest item.
-- Note: run all three parts in one session (temp tables).
-- Rule: at least 100 customers.
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

DROP TEMPORARY TABLE IF EXISTS tmp_main_category;
CREATE TEMPORARY TABLE tmp_main_category AS
SELECT 
    oi.order_id,
    COALESCE(ct.product_category_name_english, p.product_category_name, 'unlabeled') AS category_name,
    ROW_NUMBER() OVER (PARTITION BY oi.order_id
                       ORDER BY oi.price DESC) AS item_no
FROM order_items oi
INNER JOIN products p 
    ON p.product_id = oi.product_id
LEFT JOIN category_translation ct 
    ON ct.product_category_name = p.product_category_name;
CREATE INDEX idx_tmc_order_id ON tmp_main_category (order_id(32));

SELECT 
    mc.category_name AS first_order_category,
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
INNER JOIN tmp_main_category mc 
    ON mc.order_id = co.order_id
   AND mc.item_no = 1
WHERE co.order_no = 1
GROUP BY mc.category_name
HAVING total_customers >= 100
ORDER BY came_back_pct DESC;


-- ----------------------------------------------------------------------------
-- Step 2b: Repeat Buying With Enough Time to Return
-- Question: Do the Step 2 results hold for customers who had at least
--           six months to come back?
-- Note: run right after Step 2 (same temp tables). Data ends in late
--       August 2018, so a first order before March 2018 had six months.
-- ----------------------------------------------------------------------------
SELECT 
    mc.category_name AS first_order_category,
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
INNER JOIN tmp_main_category mc 
    ON mc.order_id = co.order_id
   AND mc.item_no = 1
INNER JOIN orders o 
    ON o.order_id = co.order_id
WHERE co.order_no = 1
  AND o.order_purchase_timestamp < '2018-03-01'
GROUP BY mc.category_name
HAVING total_customers >= 100
ORDER BY came_back_pct DESC;


-- ----------------------------------------------------------------------------
-- Step 3: Bad Reviews When Delivery Was On Time
-- Question: Do Electronics and Office Furniture get more 1-star reviews
--           even when the order arrives on time?
-- Note: per order, one review per order (v_one_review). 322 of 40,273
--       orders (0.80%) have two categories and count once in each.
-- Rule: at least 100 reviewed orders.
-- ----------------------------------------------------------------------------
SELECT 
    v.category_name, 
    COUNT(v.order_id) AS total_reviews, 
    ROUND(AVG(r.review_score), 2) AS avg_review,
    SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) AS one_star_count,
    ROUND(100.00 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(v.order_id), 2) AS one_star_pct
FROM (
    SELECT DISTINCT order_id, category_name
    FROM v_clean_delivered_items
) AS v
INNER JOIN v_one_review r 
    ON r.order_id = v.order_id
INNER JOIN orders o 
    ON o.order_id = v.order_id
WHERE DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
GROUP BY v.category_name
HAVING total_reviews >= 100
ORDER BY one_star_pct DESC;

-- Check: orders with more than one category (the 0.80% in the Note above).
SELECT 
    COUNT(*) AS total_orders,
    SUM(CASE WHEN n_cat > 1 THEN 1 ELSE 0 END) AS multi_category_orders,
    ROUND(100.00 * SUM(CASE WHEN n_cat > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS multi_category_pct
FROM (
    SELECT order_id, COUNT(DISTINCT category_name) AS n_cat
    FROM v_clean_delivered_items
    GROUP BY order_id
) AS t;


-- ----------------------------------------------------------------------------
-- Step 4: Freight per R$ 100 of Goods
-- Question: Is freight heavier for Electronics and Office Furniture
--           than for other categories?
-- Note: freight_to_gmv_pct = freight per R$ 100 of goods, as in Day 3.
--       Weight and volume show why some categories cost more to ship.
-- Rule: at least 100 items.
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
    ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_gmv_pct
FROM orders o
INNER JOIN order_items oi 
    ON o.order_id = oi.order_id
INNER JOIN products p 
    ON oi.product_id = p.product_id
LEFT JOIN category_translation ct 
    ON p.product_category_name = ct.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2018-01-01'
  AND o.order_purchase_timestamp <  '2018-07-01'
GROUP BY 1
HAVING total_items_sold >= 100
ORDER BY freight_to_gmv_pct DESC;


-- ----------------------------------------------------------------------------
-- Step 5: Scorecard
-- Question: Should the R$ 2M retention budget go to Electronics and
--           Office Furniture?
-- Note: each CTE is a short copy of Steps 1-4. WITH ROLLUP adds an
--       all-categories row (NULL name) as the comparison line.
-- Note: run right after Step 2, as it reuses Step 2's temp tables.
-- Note: computers added, in case "Electronics" means computers.
-- Note: home_appliances and fashion_bags_accessories added as the
--       strongest repeat categories in Step 2, for comparison.
-- ----------------------------------------------------------------------------
WITH price AS (
    SELECT 
        category_name,
        ROUND(100.00 * SUM(price) / (SELECT SUM(price) FROM v_clean_delivered_items), 2) AS gmv_share_pct,
        ROUND(AVG(price), 2) AS avg_item_price
    FROM v_clean_delivered_items
    GROUP BY category_name WITH ROLLUP
),
repeat_buy AS (
    SELECT 
        mc.category_name,
        ROUND(100.00 * SUM(CASE WHEN co.total_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS came_back_pct
    FROM tmp_customer_orders co
    INNER JOIN tmp_main_category mc 
        ON mc.order_id = co.order_id
       AND mc.item_no = 1
    WHERE co.order_no = 1
    GROUP BY mc.category_name WITH ROLLUP
),
reviews AS (
    SELECT 
        v.category_name,
        ROUND(100.00 * SUM(CASE WHEN r.review_score = 1 THEN 1 ELSE 0 END) / COUNT(v.order_id), 2) AS one_star_pct
    FROM (
        SELECT DISTINCT order_id, category_name
        FROM v_clean_delivered_items
    ) AS v
    INNER JOIN v_one_review r 
        ON r.order_id = v.order_id
    INNER JOIN orders o 
        ON o.order_id = v.order_id
    WHERE DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date)
    GROUP BY v.category_name WITH ROLLUP
),
freight AS (
    SELECT 
        COALESCE(ct.product_category_name_english, p.product_category_name, 'unlabeled') AS category_name,
        ROUND(100.00 * SUM(oi.freight_value) / SUM(oi.price), 2) AS freight_to_gmv_pct
    FROM orders o
    INNER JOIN order_items oi 
        ON o.order_id = oi.order_id
    INNER JOIN products p 
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct 
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2018-01-01'
      AND o.order_purchase_timestamp <  '2018-07-01'
    GROUP BY 1 WITH ROLLUP
)
SELECT 
    COALESCE(p.category_name, 'ALL CATEGORIES') AS category_name,
    p.gmv_share_pct,
    p.avg_item_price,
    rb.came_back_pct,
    rv.one_star_pct,
    f.freight_to_gmv_pct
FROM price p
LEFT JOIN repeat_buy rb ON rb.category_name <=> p.category_name
LEFT JOIN reviews rv    ON rv.category_name <=> p.category_name
LEFT JOIN freight f     ON f.category_name  <=> p.category_name
WHERE p.category_name IN ('electronics', 'office_furniture', 'computers',
                          'home_appliances', 'fashion_bags_accessories')
   OR p.category_name IS NULL
ORDER BY p.category_name IS NULL, p.gmv_share_pct DESC;