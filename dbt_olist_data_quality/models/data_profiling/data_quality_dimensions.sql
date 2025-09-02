{{ config(materialized='table') }}

-- Data Quality Dimensions Analysis: Completeness, Validity, Accuracy, Consistency
WITH data_quality_metrics AS (
  
  -- Customers Data Quality
  SELECT 
    'customers' as table_name,
    COUNT(*) as total_records,
    -- COMPLETENESS: Percentage of non-null critical fields
    ROUND(SAFE_DIVIDE(COUNTIF(customer_id IS NOT NULL AND customer_zip_code_prefix IS NOT NULL AND customer_city IS NOT NULL AND customer_state IS NOT NULL), COUNT(*)) * 100, 2) as completeness_score,
    -- VALIDITY: Percentage of records passing validation rules
    ROUND(SAFE_DIVIDE(COUNTIF(missing_customer_id_flag = 0 AND short_zip_code_flag = 0), COUNT(*)) * 100, 2) as validity_score,
    -- ACCURACY: Based on business rules (zip code format, state codes)
    ROUND(SAFE_DIVIDE(COUNTIF(LENGTH(CAST(customer_zip_code_prefix AS STRING)) = 5 AND customer_state IN ('SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA', 'GO', 'PE', 'CE', 'PA', 'DF', 'ES', 'MT', 'MS', 'PB', 'PI', 'AL', 'RN', 'RO', 'AM', 'AC', 'SE', 'TO', 'AP', 'RR', 'MA')), COUNT(*)) * 100, 2) as accuracy_score,
    -- CONSISTENCY: Consistency in format and naming
    ROUND(SAFE_DIVIDE(COUNTIF(REGEXP_CONTAINS(CAST(customer_zip_code_prefix AS STRING), r'^\d{5}$')), COUNT(*)) * 100, 2) as consistency_score
  FROM {{ ref('stg_customers') }}
  
  UNION ALL
  
  -- Orders Data Quality  
  SELECT 
    'orders' as table_name,
    COUNT(*) as total_records,
    -- COMPLETENESS
    ROUND(SAFE_DIVIDE(COUNTIF(order_id IS NOT NULL AND customer_id IS NOT NULL AND order_status IS NOT NULL AND order_purchase_timestamp IS NOT NULL), COUNT(*)) * 100, 2) as completeness_score,
    -- VALIDITY
    ROUND(SAFE_DIVIDE(COUNTIF(missing_order_id_flag = 0 AND invalid_approval_sequence_flag = 0), COUNT(*)) * 100, 2) as validity_score,
    -- ACCURACY: Valid order statuses and logical timestamp sequence
    ROUND(SAFE_DIVIDE(COUNTIF(order_status IN ('delivered', 'shipped', 'processing', 'canceled', 'created', 'approved', 'invoiced', 'unavailable') AND order_purchase_timestamp <= COALESCE(order_approved_at, order_purchase_timestamp)), COUNT(*)) * 100, 2) as accuracy_score,
    -- CONSISTENCY: Status naming consistency
    ROUND(SAFE_DIVIDE(COUNTIF(order_status = LOWER(order_status)), COUNT(*)) * 100, 2) as consistency_score
  FROM {{ ref('stg_orders') }}
  
  UNION ALL
  
  -- Order Items Data Quality
  SELECT 
    'order_items' as table_name,
    COUNT(*) as total_records,
    -- COMPLETENESS
    ROUND(SAFE_DIVIDE(COUNTIF(order_id IS NOT NULL AND order_item_id IS NOT NULL AND product_id IS NOT NULL AND seller_id IS NOT NULL AND price IS NOT NULL), COUNT(*)) * 100, 2) as completeness_score,
    -- VALIDITY
    ROUND(SAFE_DIVIDE(COUNTIF(missing_order_id_flag = 0 AND invalid_price_flag = 0 AND invalid_freight_flag = 0), COUNT(*)) * 100, 2) as validity_score,
    -- ACCURACY: Positive prices and logical freight costs
    ROUND(SAFE_DIVIDE(COUNTIF(price > 0 AND freight_value >= 0 AND price >= freight_value), COUNT(*)) * 100, 2) as accuracy_score,
    -- CONSISTENCY: Price formatting consistency (2 decimal places or whole numbers)
    ROUND(SAFE_DIVIDE(COUNTIF(MOD(CAST(price * 100 AS INT64), 1) = 0), COUNT(*)) * 100, 2) as consistency_score
  FROM {{ ref('stg_order_items') }}
  
  UNION ALL
  
  -- Order Payments Data Quality
  SELECT 
    'order_payments' as table_name,
    COUNT(*) as total_records,
    -- COMPLETENESS
    ROUND(SAFE_DIVIDE(COUNTIF(order_id IS NOT NULL AND payment_sequential IS NOT NULL AND payment_type IS NOT NULL AND payment_value IS NOT NULL), COUNT(*)) * 100, 2) as completeness_score,
    -- VALIDITY
    ROUND(SAFE_DIVIDE(COUNTIF(missing_order_id_flag = 0 AND invalid_payment_value_flag = 0 AND invalid_installments_flag = 0), COUNT(*)) * 100, 2) as validity_score,
    -- ACCURACY: Valid payment types and positive amounts
    ROUND(SAFE_DIVIDE(COUNTIF(payment_type IN ('credit_card', 'boleto', 'voucher', 'debit_card', 'not_defined') AND payment_value > 0), COUNT(*)) * 100, 2) as accuracy_score,
    -- CONSISTENCY: Payment type naming consistency
    ROUND(SAFE_DIVIDE(COUNTIF(payment_type = LOWER(payment_type) AND NOT REGEXP_CONTAINS(payment_type, r'\s')), COUNT(*)) * 100, 2) as consistency_score
  FROM {{ ref('stg_order_payments') }}
  
  UNION ALL
  
  -- Products Data Quality
  SELECT 
    'products' as table_name,
    COUNT(*) as total_records,
    -- COMPLETENESS
    ROUND(SAFE_DIVIDE(COUNTIF(product_id IS NOT NULL AND product_category_name IS NOT NULL), COUNT(*)) * 100, 2) as completeness_score,
    -- VALIDITY
    ROUND(SAFE_DIVIDE(COUNTIF(missing_product_id_flag = 0 AND missing_category_flag = 0), COUNT(*)) * 100, 2) as validity_score,
    -- ACCURACY: Logical dimensions and weights
    ROUND(SAFE_DIVIDE(COUNTIF((product_weight_g IS NULL OR product_weight_g > 0) AND (product_length_cm IS NULL OR product_length_cm > 0) AND (product_height_cm IS NULL OR product_height_cm > 0) AND (product_width_cm IS NULL OR product_width_cm > 0)), COUNT(*)) * 100, 2) as accuracy_score,
    -- CONSISTENCY: Category naming consistency
    ROUND(SAFE_DIVIDE(COUNTIF(product_category_name = LOWER(product_category_name)), COUNT(*)) * 100, 2) as consistency_score
  FROM {{ ref('stg_products') }}
  
  UNION ALL
  
  -- Sellers Data Quality
  SELECT 
    'sellers' as table_name,
    COUNT(*) as total_records,
    -- COMPLETENESS
    ROUND(SAFE_DIVIDE(COUNTIF(seller_id IS NOT NULL AND seller_zip_code_prefix IS NOT NULL AND seller_city IS NOT NULL AND seller_state IS NOT NULL), COUNT(*)) * 100, 2) as completeness_score,
    -- VALIDITY
    ROUND(SAFE_DIVIDE(COUNTIF(missing_seller_id_flag = 0 AND short_zip_code_flag = 0), COUNT(*)) * 100, 2) as validity_score,
    -- ACCURACY: Valid state codes and zip code format
    ROUND(SAFE_DIVIDE(COUNTIF(LENGTH(CAST(seller_zip_code_prefix AS STRING)) = 5 AND seller_state IN ('SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA', 'GO', 'PE', 'CE', 'PA', 'DF', 'ES', 'MT', 'MS', 'PB', 'PI', 'AL', 'RN', 'RO', 'AM', 'AC', 'SE', 'TO', 'AP', 'RR', 'MA')), COUNT(*)) * 100, 2) as accuracy_score,
    -- CONSISTENCY: Format consistency
    ROUND(SAFE_DIVIDE(COUNTIF(REGEXP_CONTAINS(CAST(seller_zip_code_prefix AS STRING), r'^\d{5}$')), COUNT(*)) * 100, 2) as consistency_score
  FROM {{ ref('stg_sellers') }}
)

SELECT 
  table_name,
  total_records,
  completeness_score,
  validity_score,
  accuracy_score,
  consistency_score,
  -- Overall Data Quality Score (average of all dimensions)
  ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) as overall_data_quality_score,
  -- Data Quality Grade
  CASE 
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 95 THEN 'A+'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 90 THEN 'A'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 85 THEN 'B+'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 80 THEN 'B'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 75 THEN 'C+'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 70 THEN 'C'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 65 THEN 'D+'
    WHEN ROUND((completeness_score + validity_score + accuracy_score + consistency_score) / 4, 2) >= 60 THEN 'D'
    ELSE 'F'
  END as data_quality_grade
FROM data_quality_metrics
ORDER BY overall_data_quality_score DESC
