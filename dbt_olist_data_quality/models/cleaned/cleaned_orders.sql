{{ config(materialized='table') }}

-- Clean Order Data: Validate timestamp sequences, standardize statuses
WITH cleaned_orders AS (
  SELECT 
    order_id,
    customer_id,
    
    -- Standardize order status
    LOWER(TRIM(order_status)) as order_status_clean,
    
    -- Parse timestamps with error handling  
    SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_purchase_timestamp AS STRING)) as purchase_timestamp_clean,
    SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_approved_at AS STRING)) as approved_timestamp_clean,
    SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_delivered_carrier_date AS STRING)) as carrier_timestamp_clean,
    SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_delivered_customer_date AS STRING)) as delivered_timestamp_clean,
    SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_estimated_delivery_date AS STRING)) as estimated_delivery_clean,
    
    -- Original timestamps for reference
    order_purchase_timestamp as purchase_timestamp_original,
    order_approved_at as approved_timestamp_original,
    order_delivered_carrier_date as carrier_timestamp_original,
    order_delivered_customer_date as delivered_timestamp_original,
    order_estimated_delivery_date as estimated_delivery_original,
    
    -- ETL metadata
    _sdc_batched_at,
    _loaded_at
    
  FROM {{ ref('stg_orders') }}
),

timestamp_validation AS (
  SELECT 
    *,
    
    -- Validate timestamp sequences
    CASE 
      WHEN approved_timestamp_clean IS NOT NULL 
           AND approved_timestamp_clean < purchase_timestamp_clean 
      THEN FALSE 
      ELSE TRUE 
    END as approval_sequence_valid,
    
    CASE 
      WHEN carrier_timestamp_clean IS NOT NULL 
           AND (carrier_timestamp_clean < purchase_timestamp_clean 
                OR (approved_timestamp_clean IS NOT NULL AND carrier_timestamp_clean < approved_timestamp_clean))
      THEN FALSE 
      ELSE TRUE 
    END as carrier_sequence_valid,
    
    CASE 
      WHEN delivered_timestamp_clean IS NOT NULL 
           AND (delivered_timestamp_clean < purchase_timestamp_clean 
                OR (carrier_timestamp_clean IS NOT NULL AND delivered_timestamp_clean < carrier_timestamp_clean))
      THEN FALSE 
      ELSE TRUE 
    END as delivery_sequence_valid,
    
    -- Calculate delivery times in days
    DATE_DIFF(
      DATE(delivered_timestamp_clean), 
      DATE(purchase_timestamp_clean), 
      DAY
    ) as delivery_time_days,
    
    DATE_DIFF(
      DATE(carrier_timestamp_clean), 
      DATE(purchase_timestamp_clean), 
      DAY  
    ) as shipping_time_days,
    
    -- Validate order status consistency with timestamps
    CASE 
      WHEN order_status_clean = 'delivered' AND delivered_timestamp_clean IS NULL THEN FALSE
      WHEN order_status_clean = 'shipped' AND carrier_timestamp_clean IS NULL THEN FALSE
      WHEN order_status_clean IN ('canceled', 'unavailable') AND delivered_timestamp_clean IS NOT NULL THEN FALSE
      ELSE TRUE
    END as status_timestamp_consistent
    
  FROM cleaned_orders
)

SELECT 
  order_id,
  customer_id,
  order_status_clean,
  
  -- Cleaned timestamps
  purchase_timestamp_clean,
  approved_timestamp_clean,
  carrier_timestamp_clean,
  delivered_timestamp_clean,
  estimated_delivery_clean,
  
  -- Validation flags
  approval_sequence_valid,
  carrier_sequence_valid,
  delivery_sequence_valid,
  status_timestamp_consistent,
  
  -- Business metrics
  delivery_time_days,
  shipping_time_days,
  
  -- Flag outliers
  CASE 
    WHEN delivery_time_days > 90 THEN TRUE
    WHEN delivery_time_days < 0 THEN TRUE
    ELSE FALSE
  END as delivery_time_outlier,
  
  CASE 
    WHEN shipping_time_days > 30 THEN TRUE
    WHEN shipping_time_days < 0 THEN TRUE
    ELSE FALSE
  END as shipping_time_outlier,
  
  -- Overall data quality assessment
  CASE 
    WHEN NOT approval_sequence_valid THEN 'Approval before purchase'
    WHEN NOT carrier_sequence_valid THEN 'Shipping before approval/purchase'
    WHEN NOT delivery_sequence_valid THEN 'Delivery before shipping/purchase'
    WHEN NOT status_timestamp_consistent THEN 'Status inconsistent with timestamps'
    WHEN delivery_time_days > 90 THEN 'Delivery time exceeds 90 days'
    WHEN delivery_time_days < 0 THEN 'Negative delivery time'
    ELSE NULL
  END as data_quality_issue,
  
  -- Order lifecycle stage
  CASE 
    WHEN delivered_timestamp_clean IS NOT NULL THEN 'Delivered'
    WHEN carrier_timestamp_clean IS NOT NULL THEN 'Shipped'
    WHEN approved_timestamp_clean IS NOT NULL THEN 'Approved'
    WHEN order_status_clean IN ('canceled', 'unavailable') THEN 'Canceled'
    ELSE 'Created'
  END as order_lifecycle_stage,
  
  -- Original data for audit trail
  purchase_timestamp_original,
  approved_timestamp_original,
  carrier_timestamp_original,
  delivered_timestamp_original,
  estimated_delivery_original,
  
  -- ETL metadata
  _sdc_batched_at,
  _loaded_at,
  CURRENT_TIMESTAMP() as cleaned_at

FROM timestamp_validation
