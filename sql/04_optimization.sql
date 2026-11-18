-- ShopHub E-Commerce SQL Analytics
-- 04_optimization.sql
-- Database: shophub | MySQL 8.0+
-- Run procedure DDL and EXPLAIN statements individually as noted.

USE shophub;

-- =========================================================
-- G1. Stored procedure: parameterized, validated discount calculator
-- Read-only: calculates a discounted total; does not update source prices.
-- =========================================================

DROP PROCEDURE IF EXISTS calculate_order_discount;

DELIMITER //

CREATE PROCEDURE calculate_order_discount(
    IN p_order_id VARCHAR(50),
    IN p_discount_percent DECIMAL(5,2)
)
BEGIN
    IF p_discount_percent IS NULL
       OR p_discount_percent < 0
       OR p_discount_percent > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Discount must be between 0 and 100';
    END IF;

    SELECT
        p_order_id AS order_id,
        ROUND(SUM(price + freight_value), 2) AS original_total,
        p_discount_percent AS discount_percent,
        ROUND(SUM(price + freight_value) * p_discount_percent / 100, 2)
            AS discount_amount,
        ROUND(SUM(price + freight_value) *
              (1 - p_discount_percent / 100), 2) AS discounted_total
    FROM order_items
    WHERE order_id = p_order_id
    HAVING COUNT(*) > 0;
END //

DELIMITER ;

-- Test valid input (previously verified):
-- CALL calculate_order_discount('bfbd0f9bdef84302105ad712db648a6c', 10);
-- Expected: original 143.46; discount 14.35; discounted total 129.11.

-- Test invalid input (previously verified):
-- CALL calculate_order_discount('bfbd0f9bdef84302105ad712db648a6c', 150);
-- Expected: Error 1644, "Discount must be between 0 and 100".

-- Optional: remove the procedure after testing if desired:
-- DROP PROCEDURE calculate_order_discount;


-- =========================================================
-- G2. Baseline query plan (run before any index experiment)
-- =========================================================

EXPLAIN ANALYZE
SELECT
    o.customer_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    SUM(oi.price + oi.freight_value) AS total_spending
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY o.customer_id
ORDER BY total_spending DESC
LIMIT 10;

-- Observed baseline on the user's database:
-- Actual execution time approximately 652 ms.
-- Orders table scan: 99,441 rows; delivered rows: 96,478.
-- order_items joined via PRIMARY index on order_id.


-- =========================================================
-- G3. Index experiment (NOT retained)
-- =========================================================

-- Experiment tested:
-- CREATE INDEX idx_orders_status_order
-- ON orders(order_status, order_id);
--
-- Re-ran the identical EXPLAIN ANALYZE query.
-- MySQL used the new index, but actual execution time was ~804 ms.
-- Delivered status covers ~97.02% of orders, so the predicate is
-- not selective; index access was slower than the original table scan.
--
-- The experimental index was dropped after testing:
-- DROP INDEX idx_orders_status_order ON orders;

-- Final index verification commands:
SHOW INDEX FROM orders;
SHOW INDEX FROM order_items;

-- Verified final orders indexes:
-- PRIMARY(order_id)
-- customer_id(customer_id)
--
-- Verified order_items indexes:
-- PRIMARY(order_id, order_item_id)
-- product_id(product_id)
-- seller_id(seller_id)
--
-- order_id is already the leading column of order_items' composite PK.
-- A separate order_items(order_id) index would be redundant.

-- Important: EXPLAIN ANALYZE executes the SELECT. Compare actual times
-- across repeated runs under similar server load; one timing is not
-- a universal benchmark. Do not claim the tested index improved performance.
