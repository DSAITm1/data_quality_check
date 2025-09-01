{{ config(materialized='view') }}

with source_data as (
    select 
        product_id,
        product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    from {{ source('olist_raw', 'products') }}
),

cleaned_data as (
    select 
        product_id,
        TRIM(product_category_name) as product_category_name,
        CAST(product_name_lenght as INT64) as product_name_length,
        CAST(product_description_lenght as INT64) as product_description_length,
        CAST(product_photos_qty as INT64) as product_photos_qty,
        CAST(product_weight_g as FLOAT64) as product_weight_g,
        CAST(product_length_cm as FLOAT64) as product_length_cm,
        CAST(product_height_cm as FLOAT64) as product_height_cm,
        CAST(product_width_cm as FLOAT64) as product_width_cm,
        -- Validation flags for dimensions
        CASE WHEN CAST(product_weight_g as FLOAT64) >= 0 OR product_weight_g IS NULL THEN 1 ELSE 0 END as valid_weight,
        CASE WHEN CAST(product_length_cm as FLOAT64) >= 0 OR product_length_cm IS NULL THEN 1 ELSE 0 END as valid_length,
        CASE WHEN CAST(product_height_cm as FLOAT64) >= 0 OR product_height_cm IS NULL THEN 1 ELSE 0 END as valid_height,
        CASE WHEN CAST(product_width_cm as FLOAT64) >= 0 OR product_width_cm IS NULL THEN 1 ELSE 0 END as valid_width,
        CASE WHEN CAST(product_photos_qty as INT64) >= 0 OR product_photos_qty IS NULL THEN 1 ELSE 0 END as valid_photos_qty
    from source_data
    where product_id is not null
)

select * from cleaned_data
