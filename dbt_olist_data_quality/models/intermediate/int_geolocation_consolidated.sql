{{ config(materialized='table') }}

/*
    SECTION 6: Enhanced Geolocation Consolidation & Integrity Fix
    
    Business Objectives:
    1. Consolidate geolocation to ONE lat/lng per (zip_code, city, state) combination
    2. Add missing zip codes from customers/sellers with estimated coordinates
    3. Ensure 100% referential integrity for business operations
    
    Strategy:
    - For existing zip codes: Select best representative coordinates (median/centroid)
    - For missing zip codes: Estimate coordinates based on city/state patterns
    - Maintain audit trail of all coordinate sources and estimations
*/

WITH existing_geolocation AS (
    -- Consolidate existing geolocation data to one record per (zip, city, state)
    SELECT 
        geolocation_zip_code_prefix,
        geolocation_city_normalized,
        geolocation_city_original,
        geolocation_state,
        -- Use median coordinates as representative point for business area
        PERCENTILE_CONT(geolocation_lat, 0.5) OVER (
            PARTITION BY geolocation_zip_code_prefix, geolocation_city_normalized, geolocation_state
        ) as consolidated_lat,
        PERCENTILE_CONT(geolocation_lng, 0.5) OVER (
            PARTITION BY geolocation_zip_code_prefix, geolocation_city_normalized, geolocation_state
        ) as consolidated_lng,
        COUNT(*) OVER (
            PARTITION BY geolocation_zip_code_prefix, geolocation_city_normalized, geolocation_state
        ) as original_coordinate_count,
        'existing_consolidated' as coordinate_source,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix, geolocation_city_normalized, geolocation_state
            ORDER BY geolocation_lat, geolocation_lng  -- Deterministic ordering
        ) as row_num
    FROM {{ ref('stg_geolocation') }}
),

consolidated_existing AS (
    -- Take only one record per (zip, city, state) combination
    SELECT 
        geolocation_zip_code_prefix,
        geolocation_city_normalized,
        geolocation_city_original,
        geolocation_state,
        consolidated_lat,
        consolidated_lng,
        original_coordinate_count,
        coordinate_source
    FROM existing_geolocation
    WHERE row_num = 1
),

missing_customer_zips AS (
    -- Find customer zip codes missing from geolocation
    SELECT DISTINCT
        CAST(c.customer_zip_code_prefix AS STRING) as missing_zip_code_prefix,
        c.customer_city_normalized as missing_city_normalized,
        c.customer_city_original as missing_city_original,
        c.customer_state as missing_state,
        'customer' as business_source
    FROM {{ ref('stg_customers') }} c
    LEFT JOIN consolidated_existing g 
        ON CAST(c.customer_zip_code_prefix AS STRING) = CAST(g.geolocation_zip_code_prefix AS STRING)
    WHERE g.geolocation_zip_code_prefix IS NULL
),

missing_seller_zips AS (
    -- Find seller zip codes missing from geolocation
    SELECT DISTINCT
        CAST(s.seller_zip_code_prefix AS STRING) as missing_zip_code_prefix,
        s.seller_city_normalized as missing_city_normalized,
        s.seller_city_original as missing_city_original,
        s.seller_state as missing_state,
        'seller' as business_source
    FROM {{ ref('stg_sellers') }} s
    LEFT JOIN consolidated_existing g 
        ON CAST(s.seller_zip_code_prefix AS STRING) = CAST(g.geolocation_zip_code_prefix AS STRING)
    WHERE g.geolocation_zip_code_prefix IS NULL
),

all_missing_zips AS (
    -- Combine all missing zip codes with deduplication
    SELECT 
        missing_zip_code_prefix,
        missing_city_normalized,
        missing_city_original,
        missing_state,
        STRING_AGG(DISTINCT business_source) as found_in_sources
    FROM (
        SELECT * FROM missing_customer_zips
        UNION ALL
        SELECT * FROM missing_seller_zips
    )
    GROUP BY missing_zip_code_prefix, missing_city_normalized, missing_city_original, missing_state
),

city_state_coordinate_estimates AS (
    -- Calculate average coordinates for each city/state combination for estimation
    SELECT 
        geolocation_city_normalized,
        geolocation_state,
        AVG(consolidated_lat) as avg_city_lat,
        AVG(consolidated_lng) as avg_city_lng,
        COUNT(*) as zip_codes_in_city
    FROM consolidated_existing
    GROUP BY geolocation_city_normalized, geolocation_state
    HAVING COUNT(*) >= 3  -- Only use cities with multiple zip codes for reliable estimates
),

state_coordinate_estimates AS (
    -- Fallback: Calculate average coordinates for each state
    SELECT 
        geolocation_state,
        AVG(consolidated_lat) as avg_state_lat,
        AVG(consolidated_lng) as avg_state_lng,
        COUNT(DISTINCT geolocation_city_normalized) as cities_in_state
    FROM consolidated_existing
    GROUP BY geolocation_state
),

missing_with_estimates AS (
    -- Add estimated coordinates to missing zip codes
    SELECT 
        mz.missing_zip_code_prefix as geolocation_zip_code_prefix,
        mz.missing_city_normalized as geolocation_city_normalized,
        mz.missing_city_original as geolocation_city_original,
        mz.missing_state as geolocation_state,
        -- Use city estimate if available, otherwise state estimate
        COALESCE(cce.avg_city_lat, sce.avg_state_lat) as consolidated_lat,
        COALESCE(cce.avg_city_lng, sce.avg_state_lng) as consolidated_lng,
        1 as original_coordinate_count,
        CASE 
            WHEN cce.avg_city_lat IS NOT NULL THEN 'estimated_from_city_average'
            WHEN sce.avg_state_lat IS NOT NULL THEN 'estimated_from_state_average'
            ELSE 'no_estimate_available'
        END as coordinate_source,
        mz.found_in_sources,
        cce.zip_codes_in_city,
        sce.cities_in_state
    FROM all_missing_zips mz
    LEFT JOIN city_state_coordinate_estimates cce 
        ON mz.missing_city_normalized = cce.geolocation_city_normalized 
        AND mz.missing_state = cce.geolocation_state
    LEFT JOIN state_coordinate_estimates sce 
        ON mz.missing_state = sce.geolocation_state
),

final_consolidated AS (
    -- Combine existing consolidated data with estimated missing data
    SELECT 
        geolocation_zip_code_prefix,
        geolocation_city_normalized,
        geolocation_city_original,
        geolocation_state,
        consolidated_lat,
        consolidated_lng,
        original_coordinate_count,
        coordinate_source,
        NULL as found_in_sources,
        NULL as zip_codes_in_city,
        NULL as cities_in_state,
        -- Data quality flags
        CASE 
            WHEN consolidated_lat BETWEEN -35.0 AND 5.0 
                AND consolidated_lng BETWEEN -75.0 AND -30.0 THEN 1 
            ELSE 0 
        END as valid_brazil_coordinates,
        CASE 
            WHEN coordinate_source = 'existing_consolidated' THEN 'high'
            WHEN coordinate_source = 'estimated_from_city_average' THEN 'medium'
            WHEN coordinate_source = 'estimated_from_state_average' THEN 'low'
            ELSE 'none'
        END as coordinate_confidence
    FROM consolidated_existing
    
    UNION ALL
    
    SELECT 
        geolocation_zip_code_prefix,
        geolocation_city_normalized,
        geolocation_city_original,
        geolocation_state,
        consolidated_lat,
        consolidated_lng,
        original_coordinate_count,
        coordinate_source,
        found_in_sources,
        zip_codes_in_city,
        cities_in_state,
        -- Data quality flags
        CASE 
            WHEN consolidated_lat BETWEEN -35.0 AND 5.0 
                AND consolidated_lng BETWEEN -75.0 AND -30.0 THEN 1 
            ELSE 0 
        END as valid_brazil_coordinates,
        CASE 
            WHEN coordinate_source = 'existing_consolidated' THEN 'high'
            WHEN coordinate_source = 'estimated_from_city_average' THEN 'medium'
            WHEN coordinate_source = 'estimated_from_state_average' THEN 'low'
            ELSE 'none'
        END as coordinate_confidence
    FROM missing_with_estimates
    WHERE consolidated_lat IS NOT NULL AND consolidated_lng IS NOT NULL
)

SELECT 
    geolocation_zip_code_prefix,
    geolocation_city_normalized,
    geolocation_city_original,
    geolocation_state,
    consolidated_lat,
    consolidated_lng,
    original_coordinate_count,
    coordinate_source,
    found_in_sources,
    zip_codes_in_city,
    cities_in_state,
    valid_brazil_coordinates,
    coordinate_confidence,
    -- Create business-friendly fields
    CASE 
        WHEN coordinate_confidence = 'high' THEN 'Exact Location'
        WHEN coordinate_confidence = 'medium' THEN 'City Center Estimate'
        WHEN coordinate_confidence = 'low' THEN 'State Center Estimate'
        ELSE 'No Coordinates'
    END as location_accuracy_description,
    -- Add audit timestamp
    CURRENT_TIMESTAMP() as consolidation_timestamp
FROM final_consolidated
ORDER BY coordinate_confidence DESC, geolocation_zip_code_prefix
