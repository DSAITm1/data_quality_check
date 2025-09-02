{{ config(materialized='table') }}

-- Comprehensive Data Quality Validation: Compare cleaned vs. raw data quality
WITH raw_data_quality AS (
  SELECT 
    'Raw Data' as data_type,
    'customers' as table_name,
    COUNT(*) as total_records,
    COUNTIF(missing_customer_id_flag = 1) as id_issues,
    COUNTIF(short_zip_code_flag = 1) as zip_issues,
    0 as timestamp_issues,
    0 as dimension_issues,
    0 as category_issues
  FROM {{ ref('stg_customers') }}
  
  UNION ALL
  
  SELECT 
    'Raw Data' as data_type,
    'orders' as table_name,
    COUNT(*) as total_records,
    COUNTIF(missing_order_id_flag = 1) as id_issues,
    0 as zip_issues,
    COUNTIF(invalid_approval_sequence_flag = 1) as timestamp_issues,
    0 as dimension_issues,
    0 as category_issues
  FROM {{ ref('stg_orders') }}
  
  UNION ALL
  
  SELECT 
    'Raw Data' as data_type,
    'products' as table_name,
    COUNT(*) as total_records,
    COUNTIF(missing_product_id_flag = 1) as id_issues,
    0 as zip_issues,
    0 as timestamp_issues,
    COUNTIF(invalid_weight_flag = 1 OR invalid_length_flag = 1 OR invalid_height_flag = 1 OR invalid_width_flag = 1) as dimension_issues,
    COUNTIF(missing_category_flag = 1) as category_issues
  FROM {{ ref('stg_products') }}
  
  UNION ALL
  
  SELECT 
    'Raw Data' as data_type,
    'geolocation' as table_name,
    COUNT(*) as total_records,
    COUNTIF(missing_zip_code_flag = 1) as id_issues,
    COUNTIF(short_zip_code_flag = 1) as zip_issues,
    0 as timestamp_issues,
    COUNTIF(invalid_brazil_coordinates_flag = 1) as dimension_issues,
    0 as category_issues
  FROM {{ ref('stg_geolocation') }}
),

cleaned_data_quality AS (
  SELECT 
    'Cleaned Data' as data_type,
    'customers' as table_name,
    COUNT(*) as total_records,
    COUNTIF(customer_id IS NULL) as id_issues,
    COUNTIF(LENGTH(zip_code_prefix_clean) != 5) as zip_issues,
    0 as timestamp_issues,
    0 as dimension_issues,
    0 as category_issues
  FROM {{ ref('cleaned_customers') }}
  
  UNION ALL
  
  SELECT 
    'Cleaned Data' as data_type,
    'orders' as table_name,
    COUNT(*) as total_records,
    COUNTIF(order_id IS NULL) as id_issues,
    0 as zip_issues,
    COUNTIF(NOT approval_sequence_valid OR NOT carrier_sequence_valid OR NOT delivery_sequence_valid) as timestamp_issues,
    0 as dimension_issues,
    0 as category_issues
  FROM {{ ref('cleaned_orders') }}
  
  UNION ALL
  
  SELECT 
    'Cleaned Data' as data_type,
    'products' as table_name,
    COUNT(*) as total_records,
    COUNTIF(product_id IS NULL) as id_issues,
    0 as zip_issues,
    0 as timestamp_issues,
    COUNTIF(weight_outlier_removed OR dimension_outlier_removed) as dimension_issues,
    COUNTIF(product_category_clean IS NULL) as category_issues
  FROM {{ ref('cleaned_products') }}
  
  UNION ALL
  
  SELECT 
    'Cleaned Data' as data_type,
    'geolocation' as table_name,
    COUNT(*) as total_records,
    COUNTIF(zip_code_prefix_clean IS NULL) as id_issues,
    COUNTIF(LENGTH(zip_code_prefix_clean) != 5) as zip_issues,
    0 as timestamp_issues,
    COUNTIF(NOT coordinates_valid_brazil) as dimension_issues,
    0 as category_issues
  FROM {{ ref('cleaned_geolocation') }}
),

combined_metrics AS (
  SELECT * FROM raw_data_quality
  UNION ALL
  SELECT * FROM cleaned_data_quality
)

SELECT 
  data_type,
  table_name,
  total_records,
  id_issues,
  zip_issues,
  timestamp_issues,
  dimension_issues,
  category_issues,
  -- Calculate total issues
  id_issues + zip_issues + timestamp_issues + dimension_issues + category_issues as total_issues,
  -- Calculate data quality score
  ROUND(
    (1 - SAFE_DIVIDE(id_issues + zip_issues + timestamp_issues + dimension_issues + category_issues, total_records)) * 100, 
    2
  ) as data_quality_score_pct,
  -- Calculate improvement metrics (for cleaned data)
  LAG(id_issues + zip_issues + timestamp_issues + dimension_issues + category_issues) 
    OVER (PARTITION BY table_name ORDER BY data_type) as raw_total_issues,
  LAG(total_records) 
    OVER (PARTITION BY table_name ORDER BY data_type) as raw_total_records
FROM combined_metrics
ORDER BY table_name, data_type
