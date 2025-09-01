{{ config(materialized='view') }}

with source as (
    select * from {{ source('olist_raw', 'sellers') }}
),

staged as (
    select
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state,
        _sdc_batched_at,
        
        -- Add data quality flags
        case 
            when seller_id is null then 1 
            else 0 
        end as missing_seller_id_flag,
        
        case 
            when seller_zip_code_prefix is null then 1 
            else 0 
        end as missing_zip_code_flag,
        
        case 
            when length(cast(seller_zip_code_prefix as string)) < 5 then 1 
            else 0 
        end as short_zip_code_flag,
        
        case 
            when seller_city is null or trim(seller_city) = '' then 1 
            else 0 
        end as missing_city_flag,
        
        case 
            when seller_state is null or trim(seller_state) = '' then 1 
            else 0 
        end as missing_state_flag,
        
        -- Add audit fields
        current_timestamp() as _loaded_at
        
    from source
)

select * from staged
