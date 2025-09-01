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
        CAST(order_purchase_timestamp as TIMESTAMP) as order_purchase_timestamp,
        CAST(order_approved_at as TIMESTAMP) as order_approved_at,
        CAST(order_delivered_carrier_date as TIMESTAMP) as order_delivered_carrier_date,
        CAST(order_delivered_customer_date as TIMESTAMP) as order_delivered_customer_date,
        CAST(order_estimated_delivery_date as TIMESTAMP) as order_estimated_delivery_date,
        -- Calculate temporal sequence flags for validation  
        CASE 
            WHEN order_approved_at IS NOT NULL AND order_purchase_timestamp IS NOT NULL 
                AND order_approved_at >= order_purchase_timestamp THEN 1
            WHEN order_approved_at IS NULL THEN 1  -- Allow null approved dates
            ELSE 0 
        END as valid_approval_sequence,
        CASE 
            WHEN order_delivered_carrier_date IS NOT NULL AND order_approved_at IS NOT NULL 
                AND order_delivered_carrier_date >= order_approved_at THEN 1
            WHEN order_delivered_carrier_date IS NULL THEN 1  -- Allow null carrier dates
            ELSE 0 
        END as valid_carrier_sequence,
        CASE 
            WHEN order_delivered_customer_date IS NOT NULL AND order_delivered_carrier_date IS NOT NULL 
                AND order_delivered_customer_date >= order_delivered_carrier_date THEN 1
            WHEN order_delivered_customer_date IS NULL THEN 1  -- Allow null delivery dates
            ELSE 0 
        END as valid_delivery_sequence
    from source_data
    where order_id is not null
        and customer_id is not null
)

select * from cleaned_data
