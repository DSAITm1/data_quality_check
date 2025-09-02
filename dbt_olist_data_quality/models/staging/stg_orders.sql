{{ config(materialized='view') }}

with source_data as (
    select 
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    from {{ source('olist_raw', 'orders') }}
),

cleaned_data as (
    select 
        order_id,
        customer_id,
        TRIM(UPPER(order_status)) as order_status,
        -- Parse timestamps and validate format
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_purchase_timestamp as STRING)) as order_purchase_timestamp,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_approved_at as STRING)) as order_approved_at,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_delivered_carrier_date as STRING)) as order_delivered_carrier_date,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_delivered_customer_date as STRING)) as order_delivered_customer_date,
        SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_estimated_delivery_date as STRING)) as order_estimated_delivery_date,
        -- Calculate temporal sequence flags for validation  
        CASE 
            WHEN SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_approved_at as STRING)) IS NOT NULL 
                AND SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_purchase_timestamp as STRING)) IS NOT NULL 
                AND SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_approved_at as STRING)) >= SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_purchase_timestamp as STRING)) THEN 1
            WHEN SAFE.PARSE_TIMESTAMP('%Y-%m-%d %H:%M:%S', CAST(order_approved_at as STRING)) IS NULL THEN 1  -- Allow null approved dates
            ELSE 0 
        END as valid_approval_sequence,
        1 as valid_carrier_sequence,  -- Simplified for now
        1 as valid_delivery_sequence  -- Simplified for now
    from source_data
    where order_id is not null
        and customer_id is not null
)

select * from cleaned_data
