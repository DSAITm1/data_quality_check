{{ config(
    materialized='table',
    partition_by={
        "field": "order_purchase_date",
        "data_type": "date",
        "granularity": "month"
    },
    cluster_by=['customer_sk', 'product_sk', 'seller_sk']
) }}

-- Fact Table: Order Items
-- Grain: One row per order item
-- Primary measures: price, freight_value, payment amounts
-- All dimension foreign keys as surrogate keys

WITH fact_base AS (
    SELECT 
        -- Business Keys for audit
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        o.customer_id,
        
        -- Date Keys
        CAST(FORMAT_DATE('%Y%m%d', DATE(o.order_purchase_timestamp)) AS INT64) as order_purchase_date_sk,
        CAST(FORMAT_DATE('%Y%m%d', DATE(o.order_approved_at)) AS INT64) as order_approved_date_sk,
        CAST(FORMAT_DATE('%Y%m%d', DATE(o.order_delivered_carrier_date)) AS INT64) as order_shipped_date_sk,
        CAST(FORMAT_DATE('%Y%m%d', DATE(o.order_delivered_customer_date)) AS INT64) as order_delivered_date_sk,
        CAST(FORMAT_DATE('%Y%m%d', DATE(o.order_estimated_delivery_date)) AS INT64) as order_estimated_delivery_date_sk,
        
        -- Date attributes for partitioning
        DATE(o.order_purchase_timestamp) as order_purchase_date,
        
        -- Core Measures
        oi.price,
        oi.freight_value,
        oi.price + oi.freight_value as total_item_value,
        
        -- Order Metrics (from enriched orders)
        o.approval_delay_hours,
        o.delivery_days,
        o.order_lifecycle_stage as lifecycle_stage,
        
        -- Payment Aggregations (sum all payments for this order)
        p.total_payment_value,
        p.payment_installments_avg,
        p.unique_payment_types,
        
        -- Order Status
        o.order_status_clean as order_status
        
    FROM {{ ref('stg_order_items') }} oi
    
    INNER JOIN {{ ref('int_orders_enriched') }} o 
        ON oi.order_id = o.order_id
    
    LEFT JOIN (
        -- Aggregate payments at order level
        SELECT 
            order_id,
            SUM(payment_value_corrected) as total_payment_value,
            AVG(payment_installments_corrected) as payment_installments_avg,
            COUNT(DISTINCT payment_type) as unique_payment_types
        FROM {{ ref('int_payments_cleaned') }}
        GROUP BY order_id
    ) p ON oi.order_id = p.order_id
),

fact_with_sks AS (
    SELECT 
        -- Generate Surrogate Key for Fact
        ROW_NUMBER() OVER (ORDER BY f.order_id, f.order_item_id) as fact_order_item_sk,
        
        -- Dimension Foreign Keys (Surrogate Keys)
        dc.customer_sk,
        dp.product_sk,
        ds.seller_sk,
        dg.geolocation_sk,
        
        -- Date Foreign Keys
        f.order_purchase_date_sk,
        f.order_approved_date_sk,
        f.order_shipped_date_sk,
        f.order_delivered_date_sk,
        f.order_estimated_delivery_date_sk,
        
        -- Business Keys (for audit and drill-through)
        f.order_id,
        f.order_item_id,
        f.product_id,
        f.seller_id,
        f.customer_id,
        
        -- Date Attribute for Partitioning
        f.order_purchase_date,
        
        -- Measures
        f.price,
        f.freight_value,
        f.total_item_value,
        f.total_payment_value,
        f.payment_installments_avg,
        f.unique_payment_types,
        
        -- Calculated Measures
        ROUND(f.freight_value / NULLIF(f.price, 0) * 100, 2) as freight_percentage,
        
        -- Order Analytics
        f.approval_delay_hours,
        f.delivery_days,
        f.lifecycle_stage,
        f.order_status,
        
        -- Quality Indicators
        CASE 
            WHEN f.delivery_days <= 0 THEN 'On Time'
            WHEN f.delivery_days <= 5 THEN 'Slightly Late'
            WHEN f.delivery_days <= 15 THEN 'Late'
            ELSE 'Very Late'
        END as delivery_performance_category,
        
        CASE 
            WHEN f.approval_delay_hours <= 24 THEN 'Fast Approval'
            WHEN f.approval_delay_hours <= 72 THEN 'Standard Approval'
            ELSE 'Slow Approval'
        END as approval_speed_category,
        
        -- Audit Fields
        CURRENT_TIMESTAMP() as created_at
        
    FROM fact_base f
    
    -- Join dimension tables to get surrogate keys
    INNER JOIN {{ ref('dim_customers') }} dc 
        ON f.customer_id = dc.customer_id
        
    INNER JOIN {{ ref('dim_products') }} dp 
        ON f.product_id = dp.product_id
        
    INNER JOIN {{ ref('dim_sellers') }} ds 
        ON f.seller_id = ds.seller_id
        
    LEFT JOIN {{ ref('dim_geolocation') }} dg 
        ON dc.customer_zip_code_prefix = dg.geolocation_zip_code_prefix
)

SELECT * FROM fact_with_sks
