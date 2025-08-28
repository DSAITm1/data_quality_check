{{ config(materialized='view') }}

with source as (
    select * from {{ source('olist_raw', 'public_olist_customers_dataset') }}
),

staged as (
    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state,
        _sdc_batched_at,
        
        -- Add data quality flags
        case 
            when customer_id is null then 1 
            else 0 
        end as missing_customer_id_flag,
        
        case 
            when length(cast(customer_zip_code_prefix as string)) < 5 then 1 
            else 0 
        end as short_zip_code_flag,
        
        -- Add audit fields
        current_timestamp() as _loaded_at
        
    from source
)

select * from staged
