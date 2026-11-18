-- ShopHub E-Commerce SQL Analytics
-- 03_queries.sql
-- Database: shophub | MySQL 8.0+
-- Analytical queries for Parts B-F.
-- Run statements individually. These are read-only SELECT queries.
-- Revenue convention: SUM(order_items.price + order_items.freight_value)
-- for delivered orders, attributed to order_purchase_timestamp.

USE shophub;

-- =========================================================
-- PART B: TRANSACTION / CUSTOMER / PAYMENT VALIDATION
-- =========================================================

-- B1. Customers who never placed an order
SELECT c.customer_id, c.customer_unique_id
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id
WHERE o.order_id IS NULL;

-- B2. Repeat customer identities (customer_unique_id)
SELECT customer_unique_id,
       COUNT(*) AS customer_records,
       COUNT(DISTINCT customer_id) AS distinct_customer_ids
FROM customers
GROUP BY customer_unique_id
HAVING COUNT(*) > 1
ORDER BY customer_records DESC;

-- B3. Orders with items but no payment record
SELECT o.order_id, o.order_status,
       SUM(oi.price + oi.freight_value) AS order_item_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
LEFT JOIN order_payments op ON op.order_id = o.order_id
WHERE op.order_id IS NULL
GROUP BY o.order_id, o.order_status;

-- B4. Payment total vs item + freight total reconciliation
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS item_total
    FROM order_items
    GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
)
SELECT i.order_id,
       ROUND(i.item_total, 2) AS item_total,
       ROUND(p.payment_total, 2) AS payment_total,
       ROUND(p.payment_total - i.item_total, 2) AS difference,
       CASE
         WHEN ABS(p.payment_total - i.item_total) <= 0.01 THEN 'Matched'
         WHEN p.payment_total > i.item_total THEN 'Payment Higher'
         ELSE 'Payment Lower'
       END AS reconciliation_status
FROM item_totals i
JOIN payment_totals p ON p.order_id = i.order_id
ORDER BY ABS(p.payment_total - i.item_total) DESC;

-- B5. Reconciliation summary
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS item_total
    FROM order_items GROUP BY order_id
),
payment_totals AS (
    SELECT order_id, SUM(payment_value) AS payment_total
    FROM order_payments GROUP BY order_id
),
reconciled AS (
    SELECT CASE
             WHEN ABS(p.payment_total - i.item_total) <= 0.01 THEN 'Matched'
             WHEN p.payment_total > i.item_total THEN 'Payment Higher'
             ELSE 'Payment Lower'
           END AS reconciliation_status
    FROM item_totals i
    JOIN payment_totals p ON p.order_id = i.order_id
)
SELECT reconciliation_status, COUNT(*) AS total_orders
FROM reconciled
GROUP BY reconciliation_status
ORDER BY total_orders DESC;

-- Dataset limitation: Olist customers table has no customer email or customer name.
-- Same-email/different-name validation cannot be performed with these source tables.


-- =========================================================
-- PART C: REVENUE / PRODUCT / CUSTOMER VALUE / SEASONALITY
-- =========================================================

-- C1. Monthly delivered-order revenue
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS revenue_month,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS monthly_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
ORDER BY revenue_month;

-- C2. Month-over-month change; LAG compares the previous available month.
WITH monthly AS (
    SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS revenue_month,
           SUM(oi.price + oi.freight_value) AS monthly_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
),
lagged AS (
    SELECT revenue_month, monthly_revenue,
           LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS previous_month_revenue
    FROM monthly
)
SELECT revenue_month,
       ROUND(monthly_revenue, 2) AS monthly_revenue,
       ROUND(previous_month_revenue, 2) AS previous_available_month_revenue,
       ROUND(monthly_revenue - previous_month_revenue, 2) AS revenue_change,
       ROUND(100 * (monthly_revenue - previous_month_revenue) /
             NULLIF(previous_month_revenue, 0), 2) AS mom_change_pct
FROM lagged
ORDER BY revenue_month;

-- C3. Top 10 products by delivered units sold
SELECT oi.product_id,
       COUNT(*) AS units_sold,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS product_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY oi.product_id
ORDER BY units_sold DESC, product_revenue DESC
LIMIT 10;

-- C4. Top 10 categories by delivered revenue
SELECT COALESCE(c.product_category_name_english, 'UNKNOWN CATEGORY') AS category,
       COUNT(DISTINCT oi.order_id) AS total_orders,
       COUNT(*) AS units_sold,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS category_revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN categories c ON c.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY c.product_category_name, c.product_category_name_english
ORDER BY category_revenue DESC
LIMIT 10;

-- C5. Historical customer value (not predictive lifetime value)
SELECT c.customer_unique_id,
       COUNT(DISTINCT o.order_id) AS total_orders,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS historical_spending,
       ROUND(SUM(oi.price + oi.freight_value) /
             COUNT(DISTINCT o.order_id), 2) AS average_order_value,
       MIN(o.order_purchase_timestamp) AS first_purchase_date,
       MAX(o.order_purchase_timestamp) AS last_purchase_date
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY historical_spending DESC;

-- C6. Category revenue with ROLLUP and explicit grand-total label
SELECT
    CASE
      WHEN GROUPING(c.product_category_name_english) = 1 THEN 'GRAND TOTAL'
      ELSE COALESCE(c.product_category_name_english, 'UNKNOWN CATEGORY')
    END AS category,
    ROUND(SUM(oi.price + oi.freight_value), 2) AS revenue
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
LEFT JOIN categories c ON c.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY c.product_category_name_english WITH ROLLUP;

-- C7. Revenue by calendar month across all years (unequal year coverage caveat)
SELECT MONTH(o.order_purchase_timestamp) AS month_number,
       MONTHNAME(o.order_purchase_timestamp) AS month_name,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS delivered_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY MONTH(o.order_purchase_timestamp), MONTHNAME(o.order_purchase_timestamp)
ORDER BY month_number;


-- =========================================================
-- PART D: CUSTOMER 360 / CATEGORY EXCLUSION / SELLERS / BASKET / DELIVERY
-- =========================================================

-- D1. Customer 360 summary
SELECT c.customer_unique_id,
       COUNT(DISTINCT o.order_id) AS total_orders,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS total_spending,
       ROUND(SUM(oi.price + oi.freight_value) /
             COUNT(DISTINCT o.order_id), 2) AS average_order_value,
       MIN(o.order_purchase_timestamp) AS first_purchase_date,
       MAX(o.order_purchase_timestamp) AS last_purchase_date
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY total_spending DESC;

-- D2. Customers who bought Electronics but no Books category (delivered orders)
WITH customer_categories AS (
    SELECT c.customer_unique_id,
           MAX(CASE WHEN p.product_category_name = 'eletronicos'
                    THEN 1 ELSE 0 END) AS bought_electronics,
           MAX(CASE WHEN p.product_category_name IN
                    ('livros_importados', 'livros_interesse_geral', 'livros_tecnicos')
                    THEN 1 ELSE 0 END) AS bought_books
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT customer_unique_id
FROM customer_categories
WHERE bought_electronics = 1 AND bought_books = 0;

-- D3. Each seller's top-selling product (ranked by units, then revenue)
WITH seller_product AS (
    SELECT oi.seller_id, oi.product_id,
           p.product_category_name,
           COUNT(*) AS units_sold,
           SUM(oi.price + oi.freight_value) AS product_revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    LEFT JOIN products p ON p.product_id = oi.product_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id, oi.product_id, p.product_category_name
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY seller_id
               ORDER BY units_sold DESC, product_revenue DESC
           ) AS seller_product_rank
    FROM seller_product
)
SELECT seller_id, product_id, product_category_name,
       units_sold, ROUND(product_revenue, 2) AS product_revenue
FROM ranked
WHERE seller_product_rank = 1
ORDER BY units_sold DESC
LIMIT 10;

-- D4. Frequently co-purchased product pairs (at least 2 delivered orders)
SELECT
    a.product_id AS product_1,
    b.product_id AS product_2,
    COUNT(DISTINCT a.order_id) AS orders_together
FROM order_items a
JOIN order_items b
  ON a.order_id = b.order_id
 AND a.product_id < b.product_id
JOIN orders o ON o.order_id = a.order_id
WHERE o.order_status = 'delivered'
GROUP BY a.product_id, b.product_id
HAVING COUNT(DISTINCT a.order_id) >= 2
ORDER BY orders_together DESC
LIMIT 10;

-- D5. Delivery delay by customer state; negative means earlier than estimate
SELECT c.customer_state,
       COUNT(*) AS delivered_orders,
       SUM(CASE WHEN DATEDIFF(o.order_delivered_customer_date,
                              o.order_estimated_delivery_date) > 0
                THEN 1 ELSE 0 END) AS late_orders,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date,
                          o.order_estimated_delivery_date)), 2) AS avg_days_vs_estimate
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY avg_days_vs_estimate DESC;


-- =========================================================
-- PART E: CTEs / SUBQUERIES / RECURSION / CONSECUTIVE MONTHS
-- =========================================================

-- E1. Customers spending above their state's average customer spending
WITH customer_spend AS (
    SELECT c.customer_unique_id, c.customer_state,
           SUM(oi.price + oi.freight_value) AS total_spending
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, c.customer_state
),
state_average AS (
    SELECT customer_state, AVG(total_spending) AS avg_customer_spend
    FROM customer_spend
    GROUP BY customer_state
)
SELECT cs.customer_unique_id, cs.customer_state,
       ROUND(cs.total_spending, 2) AS total_spending,
       ROUND(sa.avg_customer_spend, 2) AS state_average
FROM customer_spend cs
JOIN state_average sa ON sa.customer_state = cs.customer_state
WHERE cs.total_spending > sa.avg_customer_spend
ORDER BY cs.customer_state, cs.total_spending DESC;

-- E2. Second-highest product revenue in each category (DENSE_RANK)
WITH product_revenue AS (
    SELECT p.product_category_name, oi.product_id,
           SUM(oi.price + oi.freight_value) AS total_revenue
    FROM products p
    JOIN order_items oi ON oi.product_id = p.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY p.product_category_name, oi.product_id
),
ranked_products AS (
    SELECT *,
           DENSE_RANK() OVER (
               PARTITION BY product_category_name
               ORDER BY total_revenue DESC
           ) AS revenue_rank
    FROM product_revenue
)
SELECT product_category_name, product_id,
       ROUND(total_revenue, 2) AS total_revenue
FROM ranked_products
WHERE revenue_rank = 2
ORDER BY product_category_name;

-- E3. Demonstration-only recursive hierarchy.
-- Olist categories do not contain parent-category relationships.
WITH RECURSIVE
category_nodes AS (
    SELECT 1 AS category_id, 'Electronics' AS category_name,
           CAST(NULL AS UNSIGNED) AS parent_id
    UNION ALL SELECT 2, 'Computers', 1
    UNION ALL SELECT 3, 'Audio', 1
    UNION ALL SELECT 4, 'Laptops', 2
    UNION ALL SELECT 5, 'Desktops', 2
    UNION ALL SELECT 6, 'Headphones', 3
    UNION ALL SELECT 7, 'Speakers', 3
),
category_tree AS (
    SELECT category_id, category_name, parent_id, 1 AS hierarchy_level
    FROM category_nodes
    WHERE parent_id IS NULL

    UNION ALL

    SELECT child.category_id, child.category_name, child.parent_id,
           parent.hierarchy_level + 1
    FROM category_nodes child
    JOIN category_tree parent ON child.parent_id = parent.category_id
)
SELECT category_id, category_name, parent_id, hierarchy_level
FROM category_tree
ORDER BY category_id;

-- E4. Customers with 3 or more consecutive delivered-purchase months
WITH customer_months AS (
    SELECT DISTINCT c.customer_unique_id,
           YEAR(o.order_purchase_timestamp) * 12 +
           MONTH(o.order_purchase_timestamp) AS month_number,
           DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS purchase_month
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
numbered AS (
    SELECT *,
           month_number - ROW_NUMBER() OVER (
               PARTITION BY customer_unique_id ORDER BY month_number
           ) AS streak_group
    FROM customer_months
),
streaks AS (
    SELECT customer_unique_id,
           MIN(purchase_month) AS streak_start,
           MAX(purchase_month) AS streak_end,
           COUNT(*) AS consecutive_months
    FROM numbered
    GROUP BY customer_unique_id, streak_group
    HAVING COUNT(*) >= 3
)
SELECT *
FROM streaks
ORDER BY consecutive_months DESC, customer_unique_id;


-- =========================================================
-- PART F: WINDOW FUNCTIONS
-- =========================================================

-- F1. True 7-calendar-day moving average of daily order count.
-- Recursive calendar fills dates with zero orders.
WITH RECURSIVE date_calendar AS (
    SELECT MIN(DATE(order_purchase_timestamp)) AS calendar_date
    FROM orders
    UNION ALL
    SELECT DATE_ADD(calendar_date, INTERVAL 1 DAY)
    FROM date_calendar
    WHERE calendar_date < (
        SELECT MAX(DATE(order_purchase_timestamp)) FROM orders
    )
),
daily_orders AS (
    SELECT DATE(order_purchase_timestamp) AS order_date,
           COUNT(*) AS daily_order_count
    FROM orders
    GROUP BY DATE(order_purchase_timestamp)
),
calendar_orders AS (
    SELECT c.calendar_date AS order_date,
           COALESCE(d.daily_order_count, 0) AS daily_order_count
    FROM date_calendar c
    LEFT JOIN daily_orders d ON d.order_date = c.calendar_date
)
SELECT order_date, daily_order_count,
       ROUND(AVG(daily_order_count) OVER (
           ORDER BY order_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
       ), 2) AS moving_avg_7_days
FROM calendar_orders
ORDER BY order_date;

-- F2. Days between consecutive delivered orders per customer
WITH customer_order_dates AS (
    SELECT c.customer_unique_id, o.order_id,
           DATE(o.order_purchase_timestamp) AS purchase_date
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
),
order_gaps AS (
    SELECT customer_unique_id, order_id, purchase_date,
           LAG(purchase_date) OVER (
               PARTITION BY customer_unique_id
               ORDER BY purchase_date, order_id
           ) AS previous_purchase_date
    FROM customer_order_dates
)
SELECT customer_unique_id, order_id, previous_purchase_date,
       purchase_date,
       DATEDIFF(purchase_date, previous_purchase_date) AS days_between_orders
FROM order_gaps
WHERE previous_purchase_date IS NOT NULL
ORDER BY days_between_orders DESC;

-- F3. Top 3 sellers by delivered revenue within each seller state
WITH seller_revenue AS (
    SELECT s.seller_state, s.seller_id,
           COUNT(DISTINCT oi.order_id) AS total_orders,
           SUM(oi.price + oi.freight_value) AS total_revenue
    FROM sellers s
    JOIN order_items oi ON oi.seller_id = s.seller_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY s.seller_state, s.seller_id
),
ranked_sellers AS (
    SELECT *,
           RANK() OVER (
               PARTITION BY seller_state ORDER BY total_revenue DESC
           ) AS seller_rank
    FROM seller_revenue
)
SELECT seller_state, seller_id, total_orders,
       ROUND(total_revenue, 2) AS total_revenue, seller_rank
FROM ranked_sellers
WHERE seller_rank <= 3
ORDER BY seller_state, seller_rank;

-- F4. Daily running revenue and cumulative contribution
WITH daily_revenue AS (
    SELECT DATE(o.order_purchase_timestamp) AS order_date,
           SUM(oi.price + oi.freight_value) AS daily_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATE(o.order_purchase_timestamp)
),
revenue_running AS (
    SELECT order_date, daily_revenue,
           SUM(daily_revenue) OVER (
               ORDER BY order_date
               ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
           ) AS running_revenue,
           SUM(daily_revenue) OVER () AS total_revenue
    FROM daily_revenue
)
SELECT order_date,
       ROUND(daily_revenue, 2) AS daily_revenue,
       ROUND(running_revenue, 2) AS running_revenue,
       ROUND(100 * running_revenue / total_revenue, 2)
           AS cumulative_contribution_pct
FROM revenue_running
ORDER BY order_date;
