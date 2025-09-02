{{ config(materialized='table') }}

-- Data Profiling Summary: Row counts, null percentages, and basic statistics across all tables
WITH table_profiles AS (
  -- Customers Profile
  SELECT 
    'customers' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT customer_id) as unique_primary_keys,
    COUNTIF(customer_zip_code_prefix IS NULL) as null_field1,
    COUNTIF(customer_city IS NULL) as null_field2,
    COUNTIF(customer_state IS NULL) as null_field3,
    COUNTIF(missing_customer_id_flag = 0) as valid_data_quality1,
    COUNTIF(short_zip_code_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_customers') }}
  
  UNION ALL
  
  -- Geolocation Profile  
  SELECT 
    'geolocation' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) as unique_primary_keys,
    COUNTIF(geolocation_lat IS NULL) as null_field1,
    COUNTIF(geolocation_lng IS NULL) as null_field2,
    COUNTIF(geolocation_city IS NULL) as null_field3,
    COUNTIF(invalid_brazil_coordinates_flag = 0) as valid_data_quality1,
    COUNTIF(short_zip_code_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_geolocation') }}
  
  UNION ALL
  
  -- Orders Profile
  SELECT 
    'orders' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT order_id) as unique_primary_keys,
    COUNTIF(customer_id IS NULL) as null_field1,
    COUNTIF(order_status IS NULL) as null_field2,
    COUNTIF(order_purchase_timestamp IS NULL) as null_field3,
    COUNTIF(missing_order_id_flag = 0) as valid_data_quality1,
    COUNTIF(invalid_approval_sequence_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_orders') }}
  
  UNION ALL
  
  -- Order Items Profile
  SELECT 
    'order_items' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT CONCAT(order_id, '-', order_item_id)) as unique_primary_keys,
    COUNTIF(product_id IS NULL) as null_field1,
    COUNTIF(seller_id IS NULL) as null_field2,
    COUNTIF(price IS NULL) as null_field3,
    COUNTIF(missing_order_id_flag = 0) as valid_data_quality1,
    COUNTIF(invalid_price_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_order_items') }}
  
  UNION ALL
  
  -- Order Payments Profile
  SELECT 
    'order_payments' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT order_id) as unique_primary_keys,
    COUNTIF(payment_type IS NULL) as null_field1,
    COUNTIF(payment_value IS NULL) as null_field2,
    COUNTIF(payment_installments IS NULL) as null_field3,
    COUNTIF(missing_order_id_flag = 0) as valid_data_quality1,
    COUNTIF(invalid_payment_value_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_order_payments') }}
  
  UNION ALL
  
  -- Order Reviews Profile
  SELECT 
    'order_reviews' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT review_id) as unique_primary_keys,
    COUNTIF(order_id IS NULL) as null_field1,
    COUNTIF(review_score IS NULL) as null_field2,
    COUNTIF(review_creation_date IS NULL) as null_field3,
    COUNTIF(missing_review_id_flag = 0) as valid_data_quality1,
    COUNTIF(invalid_review_score_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_order_reviews') }}
  
  UNION ALL
  
  -- Products Profile
  SELECT 
    'products' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT product_id) as unique_primary_keys,
    COUNTIF(product_category_name IS NULL) as null_field1,
    COUNTIF(product_weight_g IS NULL) as null_field2,
    COUNTIF(product_length_cm IS NULL) as null_field3,
    COUNTIF(missing_product_id_flag = 0) as valid_data_quality1,
    COUNTIF(missing_category_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_products') }}
  
  UNION ALL
  
  -- Sellers Profile
  SELECT 
    'sellers' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT seller_id) as unique_primary_keys,
    COUNTIF(seller_zip_code_prefix IS NULL) as null_field1,
    COUNTIF(seller_city IS NULL) as null_field2,
    COUNTIF(seller_state IS NULL) as null_field3,
    COUNTIF(missing_seller_id_flag = 0) as valid_data_quality1,
    COUNTIF(short_zip_code_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_sellers') }}
  
  UNION ALL
  
  -- Category Translations Profile
  SELECT 
    'category_translations' as table_name,
    COUNT(*) as total_rows,
    COUNT(DISTINCT product_category_name) as unique_primary_keys,
    COUNTIF(product_category_name_english IS NULL) as null_field1,
    0 as null_field2, -- Not applicable
    0 as null_field3, -- Not applicable  
    COUNTIF(missing_portuguese_category_flag = 0) as valid_data_quality1,
    COUNTIF(missing_english_category_flag = 0) as valid_data_quality2
  FROM {{ ref('stg_category_translations') }}
)

SELECT 
  table_name,
  total_rows,
  unique_primary_keys,
  ROUND(SAFE_DIVIDE(null_field1, total_rows) * 100, 2) as null_percentage_field1,
  ROUND(SAFE_DIVIDE(null_field2, total_rows) * 100, 2) as null_percentage_field2,
  ROUND(SAFE_DIVIDE(null_field3, total_rows) * 100, 2) as null_percentage_field3,
  ROUND(SAFE_DIVIDE(valid_data_quality1, total_rows) * 100, 2) as data_quality_percentage1,
  ROUND(SAFE_DIVIDE(valid_data_quality2, total_rows) * 100, 2) as data_quality_percentage2,
  -- Data Quality Score: Average of all data quality flags
  ROUND((SAFE_DIVIDE(valid_data_quality1, total_rows) + SAFE_DIVIDE(valid_data_quality2, total_rows)) / 2 * 100, 2) as overall_data_quality_score
FROM table_profiles
ORDER BY table_name
