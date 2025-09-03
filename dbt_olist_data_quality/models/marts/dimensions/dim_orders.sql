{{ config(
    materialized='table',
    cluster_by=['order_status']
) }}

-- Dimension: Orders
-- Grain: One row per unique order
-- Business Key: order_id
-- Source: int_orders_enriched

WITH order_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY order_id) as order_sk,
        
        -- Business Key
        order_id,
        customer_id,
        
        -- Order Status Attributes
        order_status_clean as order_status,
        
        -- Order Analytics Attributes
        CASE 
            WHEN order_status_clean = 'DELIVERED' THEN 'Completed'
            WHEN order_status_clean = 'SHIPPED' THEN 'In Transit'
            WHEN order_status_clean = 'CANCELED' THEN 'Canceled'
            WHEN order_status_clean IN ('PROCESSING', 'INVOICED', 'APPROVED') THEN 'Processing'
            WHEN order_status_clean IN ('CREATED', 'UNAVAILABLE') THEN 'Pending'
            ELSE 'Other'
        END as order_stage,
        
        CASE 
            WHEN order_status_clean = 'DELIVERED' THEN 'Success'
            WHEN order_status_clean = 'CANCELED' THEN 'Failed'
            ELSE 'In Progress'
        END as order_outcome,
        
        -- Order Lifecycle Metrics
        CASE 
            WHEN order_status_clean = 'DELIVERED' THEN 1
            ELSE 0
        END as is_completed,
        
        CASE 
            WHEN order_status_clean = 'CANCELED' THEN 1
            ELSE 0
        END as is_canceled,
        
        -- Data lineage
        CURRENT_TIMESTAMP() as created_at,
        'int_orders_enriched' as source_model
        
    FROM {{ ref('int_orders_enriched') }}
)

SELECT * FROM order_dimension
