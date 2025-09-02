{{ config(materialized='view') }}

-- Intermediate Orders: Clean and enrich order data with business logic
WITH cleaned_orders AS (
  SELECT 
    order_id,
    customer_id,
    
    -- Standardize order status
    LOWER(TRIM(order_status)) as order_status_clean,
    
    -- Convert timestamps and handle timezone issues
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    
    -- Data quality flags (using available fields from staging)
    valid_approval_sequence,
    valid_carrier_sequence,
    valid_delivery_sequence
    
  FROM {{ ref('stg_orders') }}
),

-- Add business logic and derived fields
enriched_orders AS (
  SELECT 
    *,
    
    -- Calculate business metrics
    DATETIME_DIFF(order_approved_at, order_purchase_timestamp, HOUR) as approval_delay_hours,
    DATETIME_DIFF(order_delivered_carrier_date, order_approved_at, DAY) as carrier_pickup_days,
    DATETIME_DIFF(order_delivered_customer_date, order_delivered_carrier_date, DAY) as delivery_days,
    DATETIME_DIFF(order_delivered_customer_date, order_purchase_timestamp, DAY) as total_delivery_days,
    DATETIME_DIFF(order_estimated_delivery_date, order_delivered_customer_date, DAY) as delivery_vs_estimate_days,
    
    -- Order lifecycle stage
    CASE 
      WHEN order_status_clean = 'delivered' THEN 'Completed'
      WHEN order_status_clean IN ('shipped', 'processing', 'approved', 'invoiced') THEN 'In Progress'
      WHEN order_status_clean = 'canceled' THEN 'Canceled'
      WHEN order_status_clean = 'unavailable' THEN 'Failed'
      ELSE 'Other'
    END as order_lifecycle_stage,
    
    -- Performance indicators
    CASE 
      WHEN order_delivered_customer_date IS NOT NULL AND order_estimated_delivery_date IS NOT NULL
        AND order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
      WHEN order_delivered_customer_date IS NOT NULL AND order_estimated_delivery_date IS NOT NULL
        AND order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
      ELSE 'Unknown'
    END as delivery_performance,
    
    -- Data quality score
    CASE 
      WHEN valid_approval_sequence = 1 AND valid_carrier_sequence = 1 
        AND valid_delivery_sequence = 1 THEN 'High'
      WHEN (valid_approval_sequence + valid_carrier_sequence + valid_delivery_sequence) >= 2 THEN 'Medium'
      ELSE 'Low'
    END as data_quality_level
  FROM cleaned_orders
)

SELECT * FROM enriched_orders
