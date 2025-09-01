{{ config(materialized='view') }}

with source_data as (
    select 
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    from {{ source('olist_raw', 'order_items') }}
),

cleaned_data as (
    select 
        order_id,
        order_item_id,
        product_id,
        seller_id,
        -- Parse shipping limit date
        shipping_limit_date,
        CAST(price as FLOAT64) as price,
        CAST(freight_value as FLOAT64) as freight_value,
        -- Create composite primary key for uniqueness testing
        CONCAT(order_id, '_', CAST(order_item_id as STRING), '_', product_id, '_', seller_id) as composite_key,
        -- Business logic validation flags
        CASE WHEN CAST(price as FLOAT64) > 0 THEN 1 ELSE 0 END as valid_price,
        CASE WHEN CAST(freight_value as FLOAT64) >= 0 THEN 1 ELSE 0 END as valid_freight
    from source_data
    where order_id is not null
        and order_item_id is not null
        and product_id is not null
        and seller_id is not null
)

select * from cleaned_data
