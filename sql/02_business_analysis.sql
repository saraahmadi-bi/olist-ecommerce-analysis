/*
 Olist E-Commerce Analytics - SQL Business Analysis

 Purpose
 -------
 Answer key business questions about orders, sales, customers,
 products, sellers, payments, and delivery performance.

 Database
 --------
 MySQL: olist_ecommerce

 Notes
 -----
 This script contains read-only analytical queries.
 It does not modify the database structure or data.
*/

USE olist_ecommerce;


-- 1. ORDER STATUS DISTRIBUTION

-- Business question:
-- How many orders are in each order status?

SELECT
    order_status,
    COUNT(*) AS order_count
FROM fact_orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 2. OVERALL SALES PERFORMANCE

-- Business question:
-- What are the total number, total value, and average value
-- of delivered orders?

SELECT
    COUNT(*) AS delivered_order_count,
    ROUND(SUM(order_total_value), 2) AS total_order_value,
    ROUND(AVG(order_total_value), 2) AS average_order_value
FROM fact_orders
WHERE order_status = 'delivered';

-- 3. MONTHLY SALES TREND

-- Business question:
-- How did delivered order volume and total order value change by month?

SELECT 
    DATE_FORMAT(order_purchase_date, '%Y-%m') AS order_month,
    COUNT(*) AS delivered_order_count,
    ROUND(SUM(order_total_value), 2) AS total_order_value
FROM fact_orders
WHERE order_status = 'delivered'
GROUP BY DATE_FORMAT(order_purchase_date, '%Y-%m')
ORDER BY order_month;

-- 4. TOP PRODUCT CATEGORIES BY SALES

-- Business question:
-- Which product categories generated the highest product sales
-- from delivered orders?

SELECT
    p.product_category_name_english AS product_category,
    COUNT(*) AS delivered_item_count,
    COUNT(DISTINCT i.order_id) AS delivered_order_count,
    ROUND(SUM(i.price), 2) AS product_sales_value
FROM fact_order_items AS i
JOIN fact_orders AS o
    ON i.order_id = o.order_id
JOIN dim_products AS p
    ON i.product_id = p.product_id
WHERE o.order_status = 'delivered'
GROUP BY p.product_category_name_english
ORDER BY product_sales_value DESC
LIMIT 10;


-- 5. SALES BY CUSTOMER STATE

-- Business question:
-- Which customer states generated the highest delivered order value?

SELECT
    c.customer_state,
    COUNT(*) AS delivered_order_count,
    ROUND(SUM(o.order_total_value), 2) AS total_order_value,
    ROUND(AVG(o.order_total_value), 2) AS average_order_value
FROM fact_orders AS o
JOIN dim_customers AS c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_order_value DESC
LIMIT 10;


-- 6. TOP SELLERS BY PRODUCT SALES

-- Business question:
-- Which sellers generated the highest product sales
-- from delivered orders?

SELECT
    i.seller_id,
    s.seller_state,
    COUNT(*) AS delivered_item_count,
    COUNT(DISTINCT i.order_id) AS delivered_order_count,
    ROUND(SUM(i.price), 2) AS product_sales_value
FROM fact_order_items AS i
JOIN fact_orders AS o
    ON i.order_id = o.order_id
JOIN dim_sellers AS s
    ON i.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY
    i.seller_id,
    s.seller_state
ORDER BY product_sales_value DESC
LIMIT 10;



-- 7. DELIVERY PERFORMANCE

-- Business question:
-- What percentage of delivered orders were on time, late,
-- or missing a delivery date?

SELECT
    delivery_performance,
    COUNT(*) AS delivered_order_count,
    ROUND(
        COUNT(*) * 100.0 /
        (
            SELECT COUNT(*)
            FROM fact_orders
            WHERE order_status = 'delivered'
        ),
        2
    ) AS percentage_of_delivered_orders
FROM fact_orders
WHERE order_status = 'delivered'
GROUP BY delivery_performance
ORDER BY delivered_order_count DESC;

-- 8. DELIVERY PERFORMANCE AND REVIEW SCORE

-- Business question:
-- Do late deliveries receive lower customer review scores
-- than on-time deliveries?

SELECT
    delivery_performance,
    COUNT(*) AS reviewed_order_count,
    ROUND(AVG(review_score), 2) AS average_review_score
FROM fact_orders
WHERE order_status = 'delivered'
  AND review_score IS NOT NULL
  AND delivery_performance IN ('On Time', 'Late')
GROUP BY delivery_performance
ORDER BY average_review_score DESC;


-- 9. PAYMENT METHOD ANALYSIS

-- Business question:
-- Which payment methods were used most frequently
-- for delivered orders?

SELECT
    p.payment_type,
    COUNT(*) AS payment_transaction_count,
    COUNT(DISTINCT p.order_id) AS orders_using_payment_method,
    ROUND(SUM(p.payment_value), 2) AS total_payment_value
FROM fact_payments AS p
JOIN fact_orders AS o
    ON p.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY orders_using_payment_method DESC;


-- 10. ONE-TIME VS REPEAT CUSTOMERS

-- Business question:
-- How do one-time and repeat customers compare
-- in order activity and delivered order value?

WITH customer_order_summary AS (
    SELECT
        c.customer_unique_id,
        COUNT(*) AS delivered_order_count,
        SUM(o.order_total_value) AS total_order_value
    FROM fact_orders AS o
    JOIN dim_customers AS c
        ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN delivered_order_count = 1 THEN 'One-time Customer'
        ELSE 'Repeat Customer'
    END AS customer_type,
    COUNT(*) AS customer_count,
    SUM(delivered_order_count) AS delivered_order_count,
    ROUND(AVG(delivered_order_count), 2) AS average_orders_per_customer,
    ROUND(SUM(total_order_value), 2) AS total_order_value,
    ROUND(AVG(total_order_value), 2) AS average_customer_value
FROM customer_order_summary
GROUP BY customer_type
ORDER BY customer_count DESC;