{{ config(materialized='view') }}

with source_data as (
    select 
        order_id,
        payment_sequential,
        payment_type,
        payment_installments,
        payment_value
    from {{ source('olist_raw', 'order_payments') }}
),

cleaned_data as (
    select 
        order_id,
        payment_sequential,
        TRIM(UPPER(payment_type)) as payment_type,
        CAST(payment_installments as INT64) as payment_installments,
        CAST(payment_value as FLOAT64) as payment_value,
        -- Create composite primary key
        CONCAT(order_id, '_', CAST(payment_sequential as STRING)) as composite_payment_key,
        -- Business logic validation flags
        CASE WHEN CAST(payment_value as FLOAT64) > 0 THEN 1 ELSE 0 END as valid_payment_value,
        CASE WHEN CAST(payment_installments as INT64) >= 1 THEN 1 ELSE 0 END as valid_installments
    from source_data
    where order_id is not null
        and payment_sequential is not null
)

select * from cleaned_data
