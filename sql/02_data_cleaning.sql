-- ShopHub E-Commerce Analytics Project
-- 02_data_cleaning.sql
-- MySQL 8.0
-- Non-destructive, repeatable cleanup steps supported by the project history.
-- No customer, review, or geolocation records are deleted.

USE shophub;

-- 1. Normalize blank product category values to NULL.
UPDATE products
SET product_category_name = NULL
WHERE product_category_name IS NOT NULL
  AND TRIM(product_category_name) = '';

-- 2. Normalize non-positive product weights to NULL.
-- The recorded checks later found no non-positive weights, so this should
-- normally affect zero rows on the final cleaned dataset.
UPDATE products
SET product_weight_g = NULL
WHERE product_weight_g <= 0;

-- 3. Fill the two missing English category labels identified in the project.
-- These labels were manually supplied; validate them against your preferred
-- business glossary before presenting them as official translations.
UPDATE categories
SET product_category_name_english =
    CASE
        WHEN product_category_name = 'pc_gamer'
            THEN 'PC Gaming'
        WHEN product_category_name = 'portateis_cozinha_e_preparadores_de_alimentos'
            THEN 'Portable Kitchen and Food Preparers'
        ELSE product_category_name_english
    END
WHERE product_category_name IN (
    'pc_gamer',
    'portateis_cozinha_e_preparadores_de_alimentos'
)
AND (
    product_category_name_english IS NULL
    OR TRIM(product_category_name_english) = ''
);

-- 4. Verify the category translation result.
SELECT
    COUNT(*) AS total_categories,
    SUM(
        product_category_name_english IS NULL
        OR TRIM(product_category_name_english) = ''
    ) AS categories_missing_english_translation
FROM categories;

SELECT
    product_category_name,
    product_category_name_english
FROM categories
WHERE product_category_name IN (
    'pc_gamer',
    'portateis_cozinha_e_preparadores_de_alimentos'
);

-- Important interpretation:
-- Repeated customer_unique_id values represent multiple customer records
-- associated with the same underlying customer identity in this dataset.
-- Repeated review_id values are linked to multiple orders in the observed data.
-- Exact repeated geolocation combinations may reflect source-data grain.
-- Do not delete these records without a documented business rule.
