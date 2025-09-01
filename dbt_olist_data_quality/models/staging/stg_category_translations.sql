{{ config(materialized='view') }}

with source_data as (
    select 
        product_category_name,
        product_category_name_english
    from {{ source('olist_raw', 'product_category_name_translation') }}
),

cleaned_data as (
    select 
        -- Original Portuguese category name (trimmed)
        TRIM(product_category_name) as product_category_name,
        -- Normalized Portuguese category name for matching
        TRIM(UPPER(NORMALIZE(product_category_name, NFD))) as product_category_name_normalized,
        -- English translation (trimmed)
        TRIM(product_category_name_english) as product_category_name_english,
        -- Validation flags
        LENGTH(TRIM(product_category_name)) as portuguese_name_length,
        LENGTH(TRIM(product_category_name_english)) as english_name_length
    from source_data
    where product_category_name is not null
        and product_category_name_english is not null
)

select * from cleaned_data