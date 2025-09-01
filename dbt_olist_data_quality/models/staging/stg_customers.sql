{{ config(materialized='view') }}

with source_data as (
    select 
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    from {{ source('olist_raw', 'customers') }}
),

cleaned_data as (
    select 
        customer_id,
        customer_unique_id,
        -- Pad zip code to 5 digits for Brazilian format
        LPAD(CAST(customer_zip_code_prefix as STRING), 5, '0') as customer_zip_code_prefix,
        -- Normalize Brazilian city names: trim, normalize accents, standardize case
        TRIM(UPPER(NORMALIZE(customer_city, NFD))) as customer_city_normalized,
        customer_city as customer_city_original,
        UPPER(TRIM(customer_state)) as customer_state
    from source_data
)

select * from cleaned_data
