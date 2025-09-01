{{ config(materialized='view') }}

with source_data as (
    select 
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    from {{ source('olist_raw', 'geolocation') }}
),

cleaned_data as (
    select 
        -- Pad zip code to 5 digits for Brazilian format
        LPAD(CAST(geolocation_zip_code_prefix as STRING), 5, '0') as geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        -- Normalize Brazilian city names: trim, normalize accents, standardize case
        TRIM(UPPER(NORMALIZE(geolocation_city, NFD))) as geolocation_city_normalized,
        geolocation_city as geolocation_city_original,
        UPPER(TRIM(geolocation_state)) as geolocation_state,
        -- Create composite key for uniqueness testing
        CONCAT(
            LPAD(CAST(geolocation_zip_code_prefix as STRING), 5, '0'),
            '_',
            CAST(geolocation_lat as STRING),
            '_',
            CAST(geolocation_lng as STRING)
        ) as composite_geo_key
    from source_data
    where geolocation_zip_code_prefix is not null
        and geolocation_lat is not null 
        and geolocation_lng is not null
)

select * from cleaned_data
