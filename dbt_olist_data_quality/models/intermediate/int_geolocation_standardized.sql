{{ config(materialized='table') }}

/*
    SECTION 6: Data Cleaning Implementation
    PRIORITY 3: Geographic Coordinate Cleanup
    
    Issue: 55 location records (0.005%) outside Brazil boundaries
    Strategy: Selective Fix with Audit Trail
    
    Brazil Boundary Rules:
    - Valid Latitude Range: -35.0 to 5.0 (degrees)
    - Valid Longitude Range: -75.0 to -30.0 (degrees)
    
    Correction Logic (applied in priority order):
    1. Sign Error Correction: Fix obvious sign errors
    2. Decimal Place Shift: Fix decimal misplacement 
    3. NULL Assignment: Set to NULL if cannot be reasonably corrected
*/

WITH coordinate_validation AS (
    SELECT 
        *,
        -- Brazil boundary validation
        CASE 
            WHEN geolocation_lat BETWEEN -35.0 AND 5.0 THEN TRUE 
            ELSE FALSE 
        END as lat_valid,
        
        CASE 
            WHEN geolocation_lng BETWEEN -75.0 AND -30.0 THEN TRUE 
            ELSE FALSE 
        END as lng_valid,
        
        -- Identify correction opportunities
        CASE 
            WHEN geolocation_lat > 5.0 AND geolocation_lat < 35.0 THEN 'sign_error_lat'
            WHEN ABS(geolocation_lat) > 100 THEN 'decimal_shift_lat'
            ELSE 'no_correction'
        END as lat_correction_type,
        
        CASE 
            WHEN geolocation_lng > 30.0 AND geolocation_lng < 75.0 THEN 'sign_error_lng'
            WHEN ABS(geolocation_lng) > 100 THEN 'decimal_shift_lng'
            ELSE 'no_correction'
        END as lng_correction_type
        
    FROM {{ ref('stg_geolocation') }}
),

coordinate_corrections AS (
    SELECT 
        *,
        -- Original coordinates preserved for audit trail
        geolocation_lat as geolocation_lat_original,
        geolocation_lng as geolocation_lng_original,
        
        -- Apply correction logic (Section 6.4)
        CASE 
            -- Sign error correction: positive lat/lng in Brazil context
            WHEN lat_correction_type = 'sign_error_lat' THEN -geolocation_lat
            -- Decimal place shift: fix misplacement (e.g., -230.5 → -23.05)  
            WHEN lat_correction_type = 'decimal_shift_lat' THEN geolocation_lat / 10
            -- Keep original if already valid
            WHEN lat_valid THEN geolocation_lat
            -- Set to NULL if cannot be reasonably corrected
            ELSE NULL
        END as geolocation_lat_corrected,
        
        CASE 
            -- Sign error correction: positive lat/lng in Brazil context
            WHEN lng_correction_type = 'sign_error_lng' THEN -geolocation_lng
            -- Decimal place shift: fix misplacement
            WHEN lng_correction_type = 'decimal_shift_lng' THEN geolocation_lng / 10
            -- Keep original if already valid
            WHEN lng_valid THEN geolocation_lng
            -- Set to NULL if cannot be reasonably corrected
            ELSE NULL
        END as geolocation_lng_corrected
        
    FROM coordinate_validation
),

-- Brazilian text normalization for geographic names (Section 6.3)
geolocation_cleaned AS (
    SELECT 
        geolocation_zip_code_prefix,
        
        -- Original coordinates and text preserved
        geolocation_lat_original,
        geolocation_lng_original,
        geolocation_city_original,
        geolocation_state,
        
        -- Corrected coordinates
        geolocation_lat_corrected,
        geolocation_lng_corrected,
        
        -- Normalized geographic text using Brazilian text cleaning rules
        TRIM(REGEXP_REPLACE(
            INITCAP(LOWER(COALESCE(geolocation_city_original, ''))), 
            r'\s+', ' '
        )) as geolocation_city_normalized,
        
        TRIM(REGEXP_REPLACE(
            UPPER(COALESCE(geolocation_state, '')), 
            r'\s+', ' '
        )) as geolocation_state_normalized,
        
        -- Validation and correction metadata
        lat_valid,
        lng_valid,
        lat_correction_type,
        lng_correction_type,
        
        -- Overall coordinate quality assessment
        CASE 
            WHEN lat_valid AND lng_valid THEN 'valid_original'
            WHEN (lat_correction_type != 'no_correction' OR lng_correction_type != 'no_correction') 
                 AND geolocation_lat_corrected BETWEEN -35.0 AND 5.0 
                 AND geolocation_lng_corrected BETWEEN -75.0 AND -30.0 THEN 'corrected_valid'
            ELSE 'invalid_coordinates'
        END as coordinate_quality_status
        
    FROM coordinate_corrections
)

SELECT 
    geolocation_zip_code_prefix,
    
    -- Coordinates (original and corrected for Section 6.4)
    geolocation_lat_original,
    geolocation_lng_original,
    geolocation_lat_corrected,
    geolocation_lng_corrected,
    
    -- Geographic text (original and normalized for Section 6.3)
    geolocation_city_original,
    geolocation_state,
    geolocation_city_normalized,
    geolocation_state_normalized,
    
    -- Data quality metadata
    lat_valid,
    lng_valid,
    lat_correction_type,
    lng_correction_type,
    coordinate_quality_status,
    
    -- Section 6 audit trail
    CURRENT_TIMESTAMP() as cleaned_timestamp,
    'section_6_coordinate_cleanup_v1' as cleaning_version

FROM geolocation_cleaned
ORDER BY coordinate_quality_status DESC, geolocation_zip_code_prefix
