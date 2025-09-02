{{ config(materialized='table') }}

-- Comprehensive E-commerce Analytics Mart: Clean, enriched data for business analysis
WITH order_analytics AS (
  SELECT 
    -- Order Information
    o.order_id,
    o.order_status_clean,
    o.order_lifecycle_stage,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    o.delivery_performance,
    
    -- Timing Metrics
    o.approval_delay_hours,
    o.carrier_pickup_days,
    o.delivery_days,
    o.total_delivery_days,
    o.delivery_vs_estimate_days,
    
    -- Customer Information
    c.customer_id,
    c.customer_unique_id,
    c.customer_city_normalized as customer_city_clean,
    c.customer_state_normalized as customer_state_clean,
    c.customer_region,
    c.customer_zip_code_prefix as customer_zip_code_prefix_clean,
    
    -- Data Quality
    o.data_quality_level as order_data_quality
  FROM {{ ref('int_orders_enriched') }} o
  LEFT JOIN {{ ref('int_customers_cleaned') }} c ON o.customer_id = c.customer_id
),

-- Order Items with Product Details
order_items_enriched AS (
  SELECT 
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.price,
    oi.freight_value,
    oi.shipping_limit_date,
    
    -- Product Information
    p.product_category_name_clean,
    p.weight_category,
    p.size_category,
    p.photo_richness,
    p.product_weight_g_clean,
    p.product_volume_cubic_cm,
    
    -- Business Metrics
    oi.price + oi.freight_value as total_item_cost,
    CASE 
      WHEN oi.freight_value > 0 THEN ROUND(oi.freight_value / oi.price * 100, 2)
      ELSE 0
    END as freight_percentage,
    
    -- Data Quality
    p.data_quality_level as product_data_quality,
    
    -- Flags for analysis
    CASE WHEN oi.freight_value > (oi.price * 0.3) THEN TRUE ELSE FALSE END as is_high_freight,
    CASE WHEN oi.valid_price = 0 THEN TRUE ELSE FALSE END as has_price_issues
  FROM {{ ref('stg_order_items') }} oi
  LEFT JOIN {{ ref('int_products_enriched') }} p ON oi.product_id = p.product_id
),

-- Payment Analysis
payment_summary AS (
  SELECT 
    order_id,
    COUNT(*) as payment_methods_count,
    SUM(payment_value) as total_payment_value,
    AVG(payment_installments) as avg_installments,
    MAX(payment_installments) as max_installments,
    
    -- Payment method analysis
    COUNTIF(payment_type = 'credit_card') as credit_card_payments,
    COUNTIF(payment_type = 'boleto') as boleto_payments,
    COUNTIF(payment_type = 'voucher') as voucher_payments,
    COUNTIF(payment_type = 'debit_card') as debit_card_payments,
    
    -- Primary payment method
    ARRAY_AGG(payment_type ORDER BY payment_value DESC LIMIT 1)[OFFSET(0)] as primary_payment_method,
    
    -- Data quality
    AVG(CASE 
      WHEN order_id IS NOT NULL AND valid_payment_value = 1 THEN 1.0 
      ELSE 0.0 
    END) as payment_data_quality_score
  FROM {{ ref('stg_order_payments') }}
  GROUP BY order_id
),

-- Review Analysis  
review_summary AS (
  SELECT 
    order_id,
    review_score,
    review_creation_date,
    review_answer_timestamp,
    
    -- Review quality indicators
    CASE 
      WHEN review_score >= 4 THEN 'Positive'
      WHEN review_score = 3 THEN 'Neutral'
      WHEN review_score <= 2 THEN 'Negative'
      ELSE 'Unknown'
    END as review_sentiment,
    
    -- Review timing
    CASE 
      WHEN review_creation_date IS NOT NULL AND review_answer_timestamp IS NOT NULL 
      THEN DATETIME_DIFF(review_answer_timestamp, review_creation_date, DAY)
      ELSE NULL
    END as review_response_days
  FROM {{ ref('stg_order_reviews') }}
),

-- Final comprehensive mart
final_mart AS (
  SELECT 
    -- Order & Customer Identifiers
    oa.order_id,
    oa.customer_id,
    oa.customer_unique_id,
    
    -- Order Details
    oa.order_status_clean,
    oa.order_lifecycle_stage,
    oa.order_purchase_timestamp,
    oa.delivery_performance,
    oa.total_delivery_days,
    oa.delivery_vs_estimate_days,
    
    -- Customer Geography
    oa.customer_city_clean,
    oa.customer_state_clean,
    oa.customer_region,
    
    -- Order Items Aggregation
    COUNT(oie.order_item_id) as items_count,
    SUM(oie.price) as total_product_value,
    SUM(oie.freight_value) as total_freight_value,
    SUM(oie.total_item_cost) as total_order_value,
    AVG(oie.freight_percentage) as avg_freight_percentage,
    
    -- Product Mix Analysis
    COUNT(DISTINCT oie.product_id) as unique_products_count,
    COUNT(DISTINCT oie.seller_id) as unique_sellers_count,
    COUNT(DISTINCT oie.product_category_name_clean) as unique_categories_count,
    
    -- Product Categories (most common)
    ARRAY_AGG(DISTINCT oie.product_category_name_clean IGNORE NULLS ORDER BY oie.product_category_name_clean LIMIT 3) as top_categories,
    
    -- Weight & Size Analysis
    ARRAY_AGG(DISTINCT oie.weight_category IGNORE NULLS ORDER BY oie.weight_category LIMIT 3) as weight_categories,
    ARRAY_AGG(DISTINCT oie.size_category IGNORE NULLS ORDER BY oie.size_category LIMIT 3) as size_categories,
    
    -- Payment Information
    ps.payment_methods_count,
    ps.total_payment_value,
    ps.primary_payment_method,
    ps.avg_installments,
    ps.max_installments,
    
    -- Review Information
    rs.review_score,
    rs.review_sentiment,
    rs.review_response_days,
    
    -- Data Quality Metrics
    oa.order_data_quality,
    AVG(CASE WHEN oie.product_data_quality = 'High' THEN 1.0 WHEN oie.product_data_quality = 'Medium' THEN 0.5 ELSE 0.0 END) as avg_product_data_quality_score,
    ps.payment_data_quality_score,
    
    -- Business Flags
    COUNTIF(oie.is_high_freight) > 0 as has_high_freight_items,
    COUNTIF(oie.has_price_issues) > 0 as has_price_issues,
    
    -- Order Date Components for Analytics
    EXTRACT(YEAR FROM oa.order_purchase_timestamp) as order_year,
    EXTRACT(MONTH FROM oa.order_purchase_timestamp) as order_month,
    EXTRACT(DAYOFWEEK FROM oa.order_purchase_timestamp) as order_day_of_week,
    EXTRACT(HOUR FROM oa.order_purchase_timestamp) as order_hour
    
  FROM order_analytics oa
  LEFT JOIN order_items_enriched oie ON oa.order_id = oie.order_id
  LEFT JOIN payment_summary ps ON oa.order_id = ps.order_id
  LEFT JOIN review_summary rs ON oa.order_id = rs.order_id
  GROUP BY 
    oa.order_id, oa.customer_id, oa.customer_unique_id, oa.order_status_clean,
    oa.order_lifecycle_stage, oa.order_purchase_timestamp, oa.delivery_performance,
    oa.total_delivery_days, oa.delivery_vs_estimate_days, oa.customer_city_clean,
    oa.customer_state_clean, oa.customer_region, ps.payment_methods_count,
    ps.total_payment_value, ps.primary_payment_method, ps.avg_installments,
    ps.max_installments, rs.review_score, rs.review_sentiment, rs.review_response_days,
    oa.order_data_quality, ps.payment_data_quality_score
)

SELECT * FROM final_mart
