{{ config(materialized='table') }}

-- Final Data Quality Validation: Comprehensive pipeline quality assessment
WITH pipeline_metrics AS (
  -- Test staging layer
  SELECT 
    'staging' as layer,
    'customers' as table_name,
    COUNT(*) as row_count,
    COUNT(DISTINCT customer_id) as unique_keys,
    COUNTIF(missing_customer_id_flag = 0) as valid_records
  FROM {{ ref('stg_customers') }}
  
  UNION ALL
  
  SELECT 
    'staging' as layer,
    'orders' as table_name,
    COUNT(*) as row_count,
    COUNT(DISTINCT order_id) as unique_keys,
    COUNTIF(missing_order_id_flag = 0) as valid_records
  FROM {{ ref('stg_orders') }}
  
  UNION ALL
  
  -- Test intermediate layer
  SELECT 
    'intermediate' as layer,
    'customers_cleaned' as table_name,
    COUNT(*) as row_count,
    COUNT(DISTINCT customer_id) as unique_keys,
    COUNTIF(data_quality_level = 'High') as valid_records
  FROM {{ ref('int_customers_cleaned') }}
  
  UNION ALL
  
  SELECT 
    'intermediate' as layer,
    'orders_enriched' as table_name,
    COUNT(*) as row_count,
    COUNT(DISTINCT order_id) as unique_keys,
    COUNTIF(data_quality_level = 'High') as valid_records
  FROM {{ ref('int_orders_enriched') }}
  
  UNION ALL
  
  SELECT 
    'intermediate' as layer,
    'products_enriched' as table_name,
    COUNT(*) as row_count,
    COUNT(DISTINCT product_id) as unique_keys,
    COUNTIF(data_quality_level = 'High') as valid_records
  FROM {{ ref('int_products_enriched') }}
  
  UNION ALL
  
  -- Test marts layer
  SELECT 
    'marts' as layer,
    'ecommerce_analytics' as table_name,
    COUNT(*) as row_count,
    COUNT(DISTINCT order_id) as unique_keys,
    COUNTIF(order_data_quality = 'High' AND customer_data_quality = 'High') as valid_records
  FROM {{ ref('mart_ecommerce_analytics') }}
),

-- Business validation metrics
business_validation AS (
  SELECT
    'business_rules' as layer,
    'order_value_validation' as table_name,
    COUNT(*) as row_count,
    COUNT(*) as unique_keys,  -- Not applicable for business rules
    COUNTIF(total_order_value > 0 AND total_product_value > 0) as valid_records
  FROM {{ ref('mart_ecommerce_analytics') }}
  
  UNION ALL
  
  SELECT
    'business_rules' as layer,
    'delivery_time_validation' as table_name,
    COUNT(*) as row_count,
    COUNT(*) as unique_keys,
    COUNTIF(
      (delivery_performance = 'On Time' AND delivery_vs_estimate_days <= 0) OR
      (delivery_performance = 'Late' AND delivery_vs_estimate_days > 0) OR
      delivery_performance = 'Unknown'
    ) as valid_records
  FROM {{ ref('mart_ecommerce_analytics') }}
  WHERE order_lifecycle_stage = 'Completed'
),

-- Referential integrity validation
referential_validation AS (
  SELECT
    'referential_integrity' as layer,
    'orders_customers_join' as table_name,
    COUNT(*) as row_count,
    COUNT(*) as unique_keys,
    COUNTIF(customer_id IS NOT NULL) as valid_records
  FROM {{ ref('mart_ecommerce_analytics') }}
),

-- Final combined results
final_validation AS (
  SELECT * FROM pipeline_metrics
  UNION ALL
  SELECT * FROM business_validation  
  UNION ALL
  SELECT * FROM referential_validation
)

SELECT 
  layer,
  table_name,
  row_count,
  unique_keys,
  valid_records,
  ROUND(SAFE_DIVIDE(valid_records, row_count) * 100, 2) as data_quality_percentage,
  CASE 
    WHEN SAFE_DIVIDE(valid_records, row_count) >= 0.95 THEN 'EXCELLENT'
    WHEN SAFE_DIVIDE(valid_records, row_count) >= 0.90 THEN 'GOOD'
    WHEN SAFE_DIVIDE(valid_records, row_count) >= 0.80 THEN 'FAIR'
    ELSE 'NEEDS_IMPROVEMENT'
  END as quality_grade
FROM final_validation
ORDER BY layer, table_name
