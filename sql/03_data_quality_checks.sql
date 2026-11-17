-- ShopHub E-Commerce Analytics Project
-- 03_data_quality_checks.sql
-- MySQL 8.0
-- Read-only validation queries. Run after loading and cleaning the data.

USE shophub;

-- A. Baseline row counts
SELECT 'categories' AS table_name, COUNT(*) AS total_records FROM categories
UNION ALL SELECT 'customers', COUNT(*) FROM customers
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'geolocation', COUNT(*) FROM geolocation;

-- B. Referential integrity: each issue count should be zero.
SELECT 'Orders without customers' AS check_name, COUNT(*) AS issue_count
FROM orders o LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL
UNION ALL
SELECT 'Order items without orders', COUNT(*)
FROM order_items oi LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'Order items without products', COUNT(*)
FROM order_items oi LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL
UNION ALL
SELECT 'Order items without sellers', COUNT(*)
FROM order_items oi LEFT JOIN sellers s ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL
UNION ALL
SELECT 'Payments without orders', COUNT(*)
FROM order_payments p LEFT JOIN orders o ON p.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'Reviews without orders', COUNT(*)
FROM order_reviews r LEFT JOIN orders o ON r.order_id = o.order_id
WHERE o.order_id IS NULL
UNION ALL
SELECT 'Products with unmatched non-NULL categories', COUNT(*)
FROM products p
LEFT JOIN categories c ON p.product_category_name = c.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND c.product_category_name IS NULL;

-- C. Primary/composite-key uniqueness checks
SELECT
    COUNT(*) AS total_order_items,
    COUNT(DISTINCT CONCAT(order_id, '#', order_item_id)) AS distinct_composite_keys
FROM order_items;

SELECT
    COUNT(*) AS total_payment_rows,
    COUNT(DISTINCT CONCAT(order_id, '#', payment_sequential)) AS distinct_composite_keys
FROM order_payments;

SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS distinct_product_ids
FROM products;

SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS distinct_order_ids
FROM orders;

-- D. Customer identity repetition: informational, not an automatic duplicate error.
SELECT
    COUNT(*) AS total_customer_records,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(DISTINCT customer_unique_id) AS distinct_customer_identities
FROM customers;

SELECT
    COUNT(*) AS repeated_identity_groups,
    MAX(records_per_identity) AS maximum_records_per_identity
FROM (
    SELECT customer_unique_id, COUNT(*) AS records_per_identity
    FROM customers
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
) repeated_ids;

-- E. Product completeness and invalid values
SELECT
    COUNT(*) AS total_products,
    SUM(product_category_name IS NULL) AS missing_category,
    SUM(product_name_length IS NULL) AS missing_name_length,
    SUM(product_description_length IS NULL) AS missing_description_length,
    SUM(product_photos_qty IS NULL) AS missing_photo_quantity,
    SUM(product_weight_g IS NULL) AS missing_weight,
    SUM(product_length_cm IS NULL OR product_height_cm IS NULL
        OR product_width_cm IS NULL) AS products_with_missing_dimensions,
    SUM(product_weight_g <= 0) AS non_positive_weight,
    SUM(product_length_cm <= 0 OR product_height_cm <= 0
        OR product_width_cm <= 0) AS products_with_non_positive_dimensions
FROM products;

-- F. Order status and timestamp completeness
SELECT order_status, COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

SELECT
    order_status,
    COUNT(*) AS total_orders,
    SUM(order_approved_at IS NULL) AS missing_approval,
    SUM(order_delivered_carrier_date IS NULL) AS missing_carrier_date,
    SUM(order_delivered_customer_date IS NULL) AS missing_customer_delivery
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- G. Order timestamp sequence anomalies. Review rows; do not auto-correct.
SELECT
    SUM(order_approved_at < order_purchase_timestamp) AS approval_before_purchase,
    SUM(order_delivered_carrier_date < order_approved_at) AS carrier_before_approval,
    SUM(order_delivered_customer_date < order_delivered_carrier_date)
        AS customer_delivery_before_carrier,
    SUM(order_estimated_delivery_date < order_purchase_timestamp)
        AS estimated_delivery_before_purchase
FROM orders;

-- H. Payments: missing/zero/negative values and zero-installment records
SELECT
    COUNT(*) AS total_payment_records,
    SUM(payment_type IS NULL OR TRIM(payment_type) = '') AS missing_payment_type,
    SUM(payment_installments IS NULL) AS missing_installments,
    SUM(payment_value IS NULL) AS missing_payment_value,
    SUM(payment_value < 0) AS negative_values,
    SUM(payment_value = 0) AS zero_values,
    SUM(payment_installments = 0) AS zero_installment_rows
FROM order_payments;

-- Orders with no payment record; investigate rather than assuming fraud.
SELECT o.order_id, o.order_status, o.order_purchase_timestamp
FROM orders o
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE p.order_id IS NULL;

-- Compare order-level payment totals with item + freight totals.
-- Aggregate each table separately to avoid multiplying rows in a join.
SELECT
    o.order_id,
    o.order_status,
    COALESCE(p.total_payment, 0) AS total_payment,
    COALESCE(i.total_order_value, 0) AS total_items_plus_freight,
    ROUND(
        COALESCE(p.total_payment, 0) - COALESCE(i.total_order_value, 0),
        2
    ) AS difference
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(payment_value) AS total_payment
    FROM order_payments
    GROUP BY order_id
) p ON p.order_id = o.order_id
LEFT JOIN (
    SELECT order_id, SUM(price + freight_value) AS total_order_value
    FROM order_items
    GROUP BY order_id
) i ON i.order_id = o.order_id
WHERE ABS(
    COALESCE(p.total_payment, 0) - COALESCE(i.total_order_value, 0)
) > 0.01
ORDER BY ABS(
    COALESCE(p.total_payment, 0) - COALESCE(i.total_order_value, 0)
) DESC;

-- I. Review validation. Repeated review_id values are not automatically duplicates.
SELECT
    COUNT(*) AS total_review_records,
    SUM(review_score IS NULL) AS missing_scores,
    SUM(review_score NOT BETWEEN 1 AND 5) AS invalid_scores,
    SUM(review_creation_date IS NULL) AS missing_creation_dates,
    SUM(review_answer_timestamp IS NULL) AS missing_answer_dates,
    SUM(review_answer_timestamp < review_creation_date) AS answer_before_creation
FROM order_reviews;

SELECT
    COUNT(*) AS repeated_review_id_groups,
    SUM(record_count - 1) AS extra_records,
    MAX(record_count) AS maximum_repetition
FROM (
    SELECT review_id, COUNT(*) AS record_count
    FROM order_reviews
    WHERE review_id IS NOT NULL
    GROUP BY review_id
    HAVING COUNT(*) > 1
) repeated_reviews;

-- J. Delivery performance (delivered orders with a recorded delivery date)
SELECT
    COUNT(*) AS delivered_orders_with_delivery_date,
    SUM(order_delivered_customer_date > order_estimated_delivery_date) AS late_orders,
    SUM(order_delivered_customer_date <= order_estimated_delivery_date) AS on_time_or_early,
    ROUND(AVG(DATEDIFF(
        order_delivered_customer_date,
        order_estimated_delivery_date
    )), 2) AS average_days_vs_estimate
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

-- K. Geolocation completeness and coordinate ranges
SELECT
    COUNT(*) AS total_records,
    SUM(geolocation_zip_code_prefix IS NULL) AS missing_zip,
    SUM(geolocation_lat IS NULL) AS missing_latitude,
    SUM(geolocation_lng IS NULL) AS missing_longitude,
    SUM(geolocation_lat < -90 OR geolocation_lat > 90) AS invalid_latitude,
    SUM(geolocation_lng < -180 OR geolocation_lng > 180) AS invalid_longitude
FROM geolocation;

-- L. Exact repeated geolocation combinations: profile only; do not delete blindly.
SELECT
    COUNT(*) AS duplicate_groups,
    SUM(rows_in_group) AS rows_in_duplicate_groups,
    SUM(rows_in_group - 1) AS extra_rows
FROM (
    SELECT COUNT(*) AS rows_in_group
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix, geolocation_lat,
             geolocation_lng, geolocation_city, geolocation_state
    HAVING COUNT(*) > 1
) geo_duplicates;

-- M. Schema metadata for final documentation
SELECT
    TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, EXTRA
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'shophub'
  AND TABLE_NAME NOT LIKE 'raw_%'
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT
    TABLE_NAME, INDEX_NAME, COLUMN_NAME, NON_UNIQUE, SEQ_IN_INDEX
FROM INFORMATION_SCHEMA.STATISTICS
WHERE TABLE_SCHEMA = 'shophub'
  AND TABLE_NAME NOT LIKE 'raw_%'
ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX;

SELECT
    TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
WHERE TABLE_SCHEMA = 'shophub'
ORDER BY TABLE_NAME, CONSTRAINT_TYPE;
