-- ShopHub E-Commerce Analytics Project
-- 01_schema.sql
-- MySQL 8.0
-- Creates the cleaned analytical schema only.
-- Safe note: this script does NOT DROP existing tables or delete data.
-- CREATE TABLE IF NOT EXISTS does not modify an existing table definition.

CREATE DATABASE IF NOT EXISTS shophub;
USE shophub;

CREATE TABLE IF NOT EXISTS categories (
    product_category_name VARCHAR(150) NOT NULL,
    product_category_name_english VARCHAR(150) NULL,
    PRIMARY KEY (product_category_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS customers (
    customer_id VARCHAR(50) NOT NULL,
    customer_unique_id VARCHAR(50) NULL,
    customer_zip_code_prefix VARCHAR(5) NULL,
    customer_city VARCHAR(100) NULL,
    customer_state VARCHAR(10) NULL,
    PRIMARY KEY (customer_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS sellers (
    seller_id VARCHAR(50) NOT NULL,
    seller_zip_code_prefix VARCHAR(5) NULL,
    seller_city VARCHAR(100) NULL,
    seller_state VARCHAR(10) NULL,
    PRIMARY KEY (seller_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS products (
    product_id VARCHAR(50) NOT NULL,
    product_category_name VARCHAR(150) NULL,
    product_name_length INT NULL,
    product_description_length INT NULL,
    product_photos_qty INT NULL,
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    PRIMARY KEY (product_id),
    KEY idx_products_category (product_category_name),
    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_name)
        REFERENCES categories (product_category_name)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS orders (
    order_id VARCHAR(50) NOT NULL,
    customer_id VARCHAR(50) NULL,
    order_status VARCHAR(30) NULL,
    order_purchase_timestamp DATETIME NULL,
    order_approved_at DATETIME NULL,
    order_delivered_carrier_date DATETIME NULL,
    order_delivered_customer_date DATETIME NULL,
    order_estimated_delivery_date DATETIME NULL,
    PRIMARY KEY (order_id),
    KEY idx_orders_customer (customer_id),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers (customer_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(50) NULL,
    seller_id VARCHAR(50) NULL,
    shipping_limit_date DATETIME NULL,
    price DECIMAL(10,2) NULL,
    freight_value DECIMAL(10,2) NULL,
    PRIMARY KEY (order_id, order_item_id),
    KEY idx_order_items_product (product_id),
    KEY idx_order_items_seller (seller_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers (seller_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_payments (
    order_id VARCHAR(50) NOT NULL,
    payment_sequential INT NOT NULL,
    payment_type VARCHAR(50) NULL,
    payment_installments INT NULL,
    payment_value DECIMAL(10,2) NULL,
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS order_reviews (
    review_record_id BIGINT NOT NULL AUTO_INCREMENT,
    review_id VARCHAR(50) NULL,
    order_id VARCHAR(50) NULL,
    review_score INT NULL,
    review_comment_title TEXT NULL,
    review_comment_message TEXT NULL,
    review_creation_date DATETIME NULL,
    review_answer_timestamp DATETIME NULL,
    PRIMARY KEY (review_record_id),
    KEY idx_order_reviews_order (order_id),
    CONSTRAINT fk_order_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders (order_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS geolocation (
    geolocation_id BIGINT NOT NULL AUTO_INCREMENT,
    geolocation_zip_code_prefix VARCHAR(5) NULL,
    geolocation_lat DOUBLE NULL,
    geolocation_lng DOUBLE NULL,
    geolocation_city VARCHAR(100) NULL,
    geolocation_state VARCHAR(10) NULL,
    PRIMARY KEY (geolocation_id)
) ENGINE=InnoDB;

-- Expected cleaned schema: 9 tables, 9 primary keys, 7 foreign keys.
-- Review actual definitions before using this as a migration against an existing DB.
