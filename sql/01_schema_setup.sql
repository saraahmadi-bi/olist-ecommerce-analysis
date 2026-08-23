/*
 Olist E-Commerce Analytics - MySQL Schema Setup

 Purpose
 -------
 Clean and type the six analytical CSV tables, create primary/foreign keys,
 and validate the final relational model.

 Prerequisites
 -------------
 1. Run the CREATE DATABASE and USE statements below.
 2. Import the six complete analytical CSV files with MySQL Workbench using
    these exact table names:
       dim_customers, dim_products, dim_sellers,
       fact_orders, fact_order_items, fact_payments
 3. Import identifier, date, boolean, and nullable numeric fields as TEXT when
    using the Table Data Import Wizard. This prevents rows containing blanks
    from being skipped. The script converts them to their final SQL types.

 Expected source row counts
 --------------------------
 dim_customers:      99,441
 dim_products:       32,951
 dim_sellers:         3,095
 fact_orders:        99,441
 fact_order_items:  112,650
 fact_payments:     103,877

 Important
 ---------
 This is a reproducible setup script for a FRESH import. Do not execute the
 ALTER/ADD CONSTRAINT statements against the already-configured database,
 because its keys and constraints already exist.

*/

CREATE DATABASE IF NOT EXISTS olist_ecommerce;
USE olist_ecommerce;



-- 1. INITIAL IMPORT AUDIT

SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count
FROM dim_customers
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_sellers', COUNT(*) FROM dim_sellers
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM fact_orders
UNION ALL
SELECT 'fact_order_items', COUNT(*) FROM fact_order_items
UNION ALL
SELECT 'fact_payments', COUNT(*) FROM fact_payments;



-- 2. DIM_CUSTOMERS

-- Validate the customer grain and nullable geolocation fields.
SELECT
    COUNT(*) AS total_customers,
    COUNT(customer_id) AS non_null_customer_ids,
    COUNT(DISTINCT customer_id) AS unique_customer_ids,
    SUM(NULLIF(TRIM(customer_lat), '') IS NULL) AS missing_lat,
    SUM(NULLIF(TRIM(customer_lng), '') IS NULL) AS missing_lng
FROM dim_customers;

-- Convert blank coordinate strings to SQL NULL.
SET SQL_SAFE_UPDATES = 0;

UPDATE dim_customers
SET
    customer_lat = NULLIF(TRIM(customer_lat), ''),
    customer_lng = NULLIF(TRIM(customer_lng), '');

SET SQL_SAFE_UPDATES = 1;

-- Apply final customer data types and primary key.
ALTER TABLE dim_customers
    MODIFY customer_id VARCHAR(32) NOT NULL,
    MODIFY customer_lat DOUBLE NULL,
    MODIFY customer_lng DOUBLE NULL,
    ADD CONSTRAINT pk_dim_customers
        PRIMARY KEY (customer_id);



-- 3. DIM_SELLERS

-- Validate the seller grain and nullable geolocation fields.
SELECT
    COUNT(*) AS total_sellers,
    COUNT(seller_id) AS non_null_seller_ids,
    COUNT(DISTINCT seller_id) AS unique_seller_ids,
    SUM(NULLIF(TRIM(seller_lat), '') IS NULL) AS missing_lat,
    SUM(NULLIF(TRIM(seller_lng), '') IS NULL) AS missing_lng
FROM dim_sellers;

-- Convert blank coordinate strings to SQL NULL.
SET SQL_SAFE_UPDATES = 0;

UPDATE dim_sellers
SET
    seller_lat = NULLIF(TRIM(seller_lat), ''),
    seller_lng = NULLIF(TRIM(seller_lng), '');

SET SQL_SAFE_UPDATES = 1;

-- Apply final seller data types and primary key.
ALTER TABLE dim_sellers
    MODIFY seller_id VARCHAR(32) NOT NULL,
    MODIFY seller_lat DOUBLE NULL,
    MODIFY seller_lng DOUBLE NULL,
    ADD CONSTRAINT pk_dim_sellers
        PRIMARY KEY (seller_id);


-- 4. DIM_PRODUCTS

-- Correct misspellings inherited from the original Olist source columns.
ALTER TABLE dim_products
    RENAME COLUMN product_name_lenght TO product_name_length;

ALTER TABLE dim_products
    RENAME COLUMN product_description_lenght TO product_description_length;

-- Validate product identifiers, categories, and nullable numeric attributes.
SELECT
    COUNT(*) AS total_products,
    COUNT(product_id) AS non_null_product_ids,
    COUNT(DISTINCT product_id) AS unique_product_ids,
    MAX(CHAR_LENGTH(product_id)) AS max_product_id_length,
    SUM(NULLIF(TRIM(product_category_name), '') IS NULL)
        AS missing_category_names,
    SUM(NULLIF(TRIM(product_category_name_english), '') IS NULL)
        AS missing_english_category_names,
    SUM(NULLIF(TRIM(product_name_length), '') IS NULL)
        AS missing_name_length,
    SUM(NULLIF(TRIM(product_description_length), '') IS NULL)
        AS missing_description_length,
    SUM(NULLIF(TRIM(product_photos_qty), '') IS NULL)
        AS missing_photos_qty,
    SUM(NULLIF(TRIM(product_weight_g), '') IS NULL)
        AS missing_weight,
    SUM(NULLIF(TRIM(product_length_cm), '') IS NULL)
        AS missing_length,
    SUM(NULLIF(TRIM(product_height_cm), '') IS NULL)
        AS missing_height,
    SUM(NULLIF(TRIM(product_width_cm), '') IS NULL)
        AS missing_width,
    SUM(NULLIF(TRIM(product_weight_kg), '') IS NULL)
        AS missing_weight_kg,
    SUM(NULLIF(TRIM(product_volume_cm3), '') IS NULL)
        AS missing_volume
FROM dim_products;

-- Convert blank numeric strings to SQL NULL.
SET SQL_SAFE_UPDATES = 0;

UPDATE dim_products
SET
    product_name_length = NULLIF(TRIM(product_name_length), ''),
    product_description_length =
        NULLIF(TRIM(product_description_length), ''),
    product_photos_qty = NULLIF(TRIM(product_photos_qty), ''),
    product_weight_g = NULLIF(TRIM(product_weight_g), ''),
    product_length_cm = NULLIF(TRIM(product_length_cm), ''),
    product_height_cm = NULLIF(TRIM(product_height_cm), ''),
    product_width_cm = NULLIF(TRIM(product_width_cm), ''),
    product_weight_kg = NULLIF(TRIM(product_weight_kg), ''),
    product_volume_cm3 = NULLIF(TRIM(product_volume_cm3), '');

SET SQL_SAFE_UPDATES = 1;

-- Apply final product data types and primary key.
ALTER TABLE dim_products
    MODIFY product_id VARCHAR(32) NOT NULL,
    MODIFY product_category_name VARCHAR(60) NOT NULL,
    MODIFY product_category_name_english VARCHAR(60) NOT NULL,
    MODIFY product_name_length INT UNSIGNED NULL,
    MODIFY product_description_length INT UNSIGNED NULL,
    MODIFY product_photos_qty INT UNSIGNED NULL,
    MODIFY product_weight_g DECIMAL(12,2) NULL,
    MODIFY product_length_cm DECIMAL(10,2) NULL,
    MODIFY product_height_cm DECIMAL(10,2) NULL,
    MODIFY product_width_cm DECIMAL(10,2) NULL,
    MODIFY product_weight_kg DECIMAL(10,3) NULL,
    MODIFY product_volume_cm3 DECIMAL(14,2) NULL,
    ADD CONSTRAINT pk_dim_products
        PRIMARY KEY (product_id);


-- 5. FACT_ORDERS

-- Validate the order grain and key text fields before conversion.
SELECT
    COUNT(*) AS total_orders,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(DISTINCT order_id) AS unique_order_ids,
    MAX(CHAR_LENGTH(order_id)) AS max_order_id_length,
    COUNT(customer_id) AS non_null_customer_ids,
    MAX(CHAR_LENGTH(customer_id)) AS max_customer_id_length,
    SUM(NULLIF(TRIM(order_status), '') IS NULL) AS missing_order_status,
    MAX(CHAR_LENGTH(order_status)) AS max_order_status_length,
    SUM(NULLIF(TRIM(delivery_performance), '') IS NULL)
        AS missing_delivery_performance,
    MAX(CHAR_LENGTH(delivery_performance))
        AS max_delivery_performance_length,
    SUM(NULLIF(TRIM(payment_reconciliation_status), '') IS NULL)
        AS missing_payment_status,
    MAX(CHAR_LENGTH(payment_reconciliation_status))
        AS max_payment_status_length
FROM fact_orders;

-- Convert blank nullable fields to NULL and boolean text to 1/0/NULL.
SET SQL_SAFE_UPDATES = 0;

UPDATE fact_orders
SET
    order_approved_at = NULLIF(TRIM(order_approved_at), ''),
    order_delivered_carrier_date =
        NULLIF(TRIM(order_delivered_carrier_date), ''),
    order_delivered_customer_date =
        NULLIF(TRIM(order_delivered_customer_date), ''),
    delivery_time_days = NULLIF(TRIM(delivery_time_days), ''),
    delivery_delay_days = NULLIF(TRIM(delivery_delay_days), ''),
    product_value = NULLIF(TRIM(product_value), ''),
    freight_value = NULLIF(TRIM(freight_value), ''),
    order_total_value = NULLIF(TRIM(order_total_value), ''),
    total_payment = NULLIF(TRIM(total_payment), ''),
    payment_difference = NULLIF(TRIM(payment_difference), ''),
    review_score = NULLIF(TRIM(review_score), ''),
    review_creation_date = NULLIF(TRIM(review_creation_date), ''),
    review_answer_timestamp = NULLIF(TRIM(review_answer_timestamp), ''),
    has_item_data =
        CASE LOWER(TRIM(has_item_data))
            WHEN 'true' THEN 1
            WHEN 'false' THEN 0
            ELSE NULL
        END,
    has_payment_data =
        CASE LOWER(TRIM(has_payment_data))
            WHEN 'true' THEN 1
            WHEN 'false' THEN 0
            ELSE NULL
        END,
    has_review_comment =
        CASE LOWER(TRIM(has_review_comment))
            WHEN 'true' THEN 1
            WHEN 'false' THEN 0
            ELSE NULL
        END,
    has_review_data =
        CASE LOWER(TRIM(has_review_data))
            WHEN 'true' THEN 1
            WHEN 'false' THEN 0
            ELSE NULL
        END;

SET SQL_SAFE_UPDATES = 1;

-- Apply final order data types and primary key.
ALTER TABLE fact_orders
    MODIFY order_id VARCHAR(32) NOT NULL,
    MODIFY customer_id VARCHAR(32) NOT NULL,
    MODIFY order_status VARCHAR(20) NOT NULL,
    MODIFY order_purchase_timestamp DATETIME NOT NULL,
    MODIFY order_approved_at DATETIME NULL,
    MODIFY order_delivered_carrier_date DATETIME NULL,
    MODIFY order_delivered_customer_date DATETIME NULL,
    MODIFY order_estimated_delivery_date DATE NOT NULL,
    MODIFY delivery_time_days DECIMAL(10,2) NULL,
    MODIFY delivery_delay_days DECIMAL(10,2) NULL,
    MODIFY delivery_performance VARCHAR(30) NOT NULL,
    MODIFY item_count INT UNSIGNED NOT NULL,
    MODIFY product_value DECIMAL(12,2) NULL,
    MODIFY freight_value DECIMAL(12,2) NULL,
    MODIFY order_total_value DECIMAL(12,2) NULL,
    MODIFY has_item_data TINYINT(1) NOT NULL,
    MODIFY total_payment DECIMAL(12,2) NULL,
    MODIFY payment_count INT UNSIGNED NOT NULL,
    MODIFY payment_method_count INT UNSIGNED NOT NULL,
    MODIFY max_installments INT UNSIGNED NOT NULL,
    MODIFY has_payment_data TINYINT(1) NOT NULL,
    MODIFY payment_difference DECIMAL(12,2) NULL,
    MODIFY payment_reconciliation_status VARCHAR(30) NOT NULL,
    MODIFY review_score TINYINT UNSIGNED NULL,
    MODIFY has_review_comment TINYINT(1) NULL,
    MODIFY review_creation_date DATETIME NULL,
    MODIFY review_answer_timestamp DATETIME NULL,
    MODIFY has_review_data TINYINT(1) NOT NULL,
    MODIFY order_purchase_date DATE NOT NULL,
    ADD CONSTRAINT pk_fact_orders
        PRIMARY KEY (order_id);


-- 6. FACT_ORDER_ITEMS

-- Validate the item grain and required fields before conversion.
SELECT
    COUNT(*) AS total_item_rows,
    COUNT(order_id) AS non_null_order_ids,
    COUNT(order_item_id) AS non_null_order_item_ids,
    COUNT(product_id) AS non_null_product_ids,
    COUNT(seller_id) AS non_null_seller_ids,
    COUNT(DISTINCT order_id, order_item_id) AS unique_order_item_keys,
    SUM(NULLIF(TRIM(shipping_limit_date), '') IS NULL)
        AS missing_shipping_dates,
    SUM(price IS NULL) AS missing_prices,
    SUM(freight_value IS NULL) AS missing_freight_values,
    SUM(item_total IS NULL) AS missing_item_totals
FROM fact_order_items;

-- Validate the timestamp format before changing the column type.
SELECT
    MIN(shipping_limit_date) AS earliest_shipping_limit,
    MAX(shipping_limit_date) AS latest_shipping_limit,
    SUM(
        STR_TO_DATE(
            TRIM(shipping_limit_date),
            '%Y-%m-%d %H:%i:%s'
        ) IS NULL
    ) AS invalid_shipping_dates
FROM fact_order_items;

-- Apply final item data types and composite primary key.
ALTER TABLE fact_order_items
    MODIFY order_id VARCHAR(32) NOT NULL,
    MODIFY order_item_id INT NOT NULL,
    MODIFY product_id VARCHAR(32) NOT NULL,
    MODIFY seller_id VARCHAR(32) NOT NULL,
    MODIFY shipping_limit_date DATETIME NOT NULL,
    MODIFY price DECIMAL(12,2) NOT NULL,
    MODIFY freight_value DECIMAL(12,2) NOT NULL,
    MODIFY item_total DECIMAL(12,2) NOT NULL,
    ADD CONSTRAINT pk_fact_order_items
        PRIMARY KEY (order_id, order_item_id);


-- 7. FACT_PAYMENTS

-- Validate the payment grain and required fields before conversion.
SELECT
    COUNT(*) AS total_payment_rows,
    COUNT(order_id) AS non_null_order_ids,
    MAX(CHAR_LENGTH(order_id)) AS max_order_id_length,
    COUNT(payment_sequential) AS non_null_payment_sequences,
    COUNT(DISTINCT order_id, payment_sequential)
        AS unique_payment_keys,
    SUM(NULLIF(TRIM(payment_type), '') IS NULL)
        AS missing_payment_types,
    MAX(CHAR_LENGTH(payment_type)) AS max_payment_type_length,
    SUM(payment_installments IS NULL) AS missing_installments,
    SUM(payment_value IS NULL) AS missing_payment_values
FROM fact_payments;

-- Apply final payment data types and composite primary key.
ALTER TABLE fact_payments
    MODIFY order_id VARCHAR(32) NOT NULL,
    MODIFY payment_sequential INT UNSIGNED NOT NULL,
    MODIFY payment_type VARCHAR(20) NOT NULL,
    MODIFY payment_installments INT UNSIGNED NOT NULL,
    MODIFY payment_value DECIMAL(12,2) NOT NULL,
    ADD CONSTRAINT pk_fact_payments
        PRIMARY KEY (order_id, payment_sequential);


-- 8. FOREIGN KEYS

-- Verify that all child values have matching parent records.
SELECT
    'fact_orders -> dim_customers' AS relationship_name,
    COUNT(*) AS orphan_rows
FROM fact_orders AS o
LEFT JOIN dim_customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT
    'fact_order_items -> fact_orders',
    COUNT(*)
FROM fact_order_items AS i
LEFT JOIN fact_orders AS o
    ON i.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'fact_order_items -> dim_products',
    COUNT(*)
FROM fact_order_items AS i
LEFT JOIN dim_products AS p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'fact_order_items -> dim_sellers',
    COUNT(*)
FROM fact_order_items AS i
LEFT JOIN dim_sellers AS s
    ON i.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL

SELECT
    'fact_payments -> fact_orders',
    COUNT(*)
FROM fact_payments AS p
LEFT JOIN fact_orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Create the five model relationships.
ALTER TABLE fact_orders
    ADD CONSTRAINT fk_fact_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES dim_customers(customer_id);

ALTER TABLE fact_order_items
    ADD CONSTRAINT fk_fact_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES fact_orders(order_id),
    ADD CONSTRAINT fk_fact_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES dim_products(product_id),
    ADD CONSTRAINT fk_fact_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES dim_sellers(seller_id);

ALTER TABLE fact_payments
    ADD CONSTRAINT fk_fact_payments_order
        FOREIGN KEY (order_id)
        REFERENCES fact_orders(order_id);


-- 9. FINAL DATABASE VALIDATION

-- Confirm final row counts.
SELECT 'dim_customers' AS table_name, COUNT(*) AS row_count
FROM dim_customers
UNION ALL
SELECT 'dim_products', COUNT(*) FROM dim_products
UNION ALL
SELECT 'dim_sellers', COUNT(*) FROM dim_sellers
UNION ALL
SELECT 'fact_orders', COUNT(*) FROM fact_orders
UNION ALL
SELECT 'fact_order_items', COUNT(*) FROM fact_order_items
UNION ALL
SELECT 'fact_payments', COUNT(*) FROM fact_payments;

-- Confirm all primary keys and their column order.
SELECT
    TABLE_NAME,
    INDEX_NAME AS key_name,
    SEQ_IN_INDEX,
    COLUMN_NAME
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA = 'olist_ecommerce'
  AND INDEX_NAME = 'PRIMARY'
  AND TABLE_NAME IN (
      'dim_customers',
      'dim_products',
      'dim_sellers',
      'fact_orders',
      'fact_order_items',
      'fact_payments'
  )
ORDER BY TABLE_NAME, SEQ_IN_INDEX;

-- Confirm all foreign keys.
SELECT
    TABLE_NAME AS child_table,
    CONSTRAINT_NAME,
    COLUMN_NAME AS foreign_key_column,
    REFERENCED_TABLE_NAME AS parent_table,
    REFERENCED_COLUMN_NAME AS referenced_column
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'olist_ecommerce'
  AND REFERENCED_TABLE_NAME IS NOT NULL
ORDER BY TABLE_NAME, CONSTRAINT_NAME;

-- Confirm that no orphan records remain after creating the foreign keys.
SELECT
    'fact_orders -> dim_customers' AS relationship_name,
    COUNT(*) AS orphan_rows
FROM fact_orders AS o
LEFT JOIN dim_customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL

UNION ALL

SELECT
    'fact_order_items -> fact_orders',
    COUNT(*)
FROM fact_order_items AS i
LEFT JOIN fact_orders AS o
    ON i.order_id = o.order_id
WHERE o.order_id IS NULL

UNION ALL

SELECT
    'fact_order_items -> dim_products',
    COUNT(*)
FROM fact_order_items AS i
LEFT JOIN dim_products AS p
    ON i.product_id = p.product_id
WHERE p.product_id IS NULL

UNION ALL

SELECT
    'fact_order_items -> dim_sellers',
    COUNT(*)
FROM fact_order_items AS i
LEFT JOIN dim_sellers AS s
    ON i.seller_id = s.seller_id
WHERE s.seller_id IS NULL

UNION ALL

SELECT
    'fact_payments -> fact_orders',
    COUNT(*)
FROM fact_payments AS p
LEFT JOIN fact_orders AS o
    ON p.order_id = o.order_id
WHERE o.order_id IS NULL;

-- Confirm that only the six intended analytical tables exist.
SHOW TABLES FROM olist_ecommerce;
