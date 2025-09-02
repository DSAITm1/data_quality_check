{{ config(materialized='table') }}

-- Clean Geolocation Data: Fix zip codes, validate coordinates, normalize text
WITH cleaned_geolocation AS (
  SELECT 
    -- Standardize zip code: pad with leading zeros if needed
    CASE 
      WHEN LENGTH(CAST(geolocation_zip_code_prefix AS STRING)) = 4 
      THEN CONCAT('0', CAST(geolocation_zip_code_prefix AS STRING))
      ELSE CAST(geolocation_zip_code_prefix AS STRING)
    END as zip_code_prefix_clean,
    
    -- Original and cleaned coordinates
    geolocation_lat,
    geolocation_lng,
    
    -- Validate coordinates are within Brazil bounds
    CASE 
      WHEN geolocation_lat BETWEEN -33.7 AND 5.3 
           AND geolocation_lng BETWEEN -73.9 AND -28.8 
      THEN TRUE 
      ELSE FALSE 
    END as coordinates_valid_brazil,
    
    -- Clean city name: normalize case, remove accents
    TRIM(LOWER(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(geolocation_city, r'[áàâã]', 'a'),
              r'[éèê]', 'e'),
            r'[íìî]', 'i'),
          r'[óòôõ]', 'o'),
        r'[úùû]', 'u')
    )) as city_name_clean,
    
    -- Clean state: ensure uppercase, validate
    UPPER(TRIM(geolocation_state)) as state_clean,
    
    -- Validate state codes
    CASE 
      WHEN UPPER(TRIM(geolocation_state)) IN (
        'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 
        'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 
        'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
      ) 
      THEN TRUE 
      ELSE FALSE 
    END as state_code_valid,
    
    -- Original data for reference
    geolocation_zip_code_prefix as zip_code_original,
    geolocation_city as city_name_original,
    geolocation_state as state_original,
    
    -- ETL metadata
    _sdc_batched_at,
    _loaded_at
    
  FROM {{ ref('stg_geolocation') }}
),

-- Create lookup for most common city/state per zip code
zip_city_lookup AS (
  SELECT 
    zip_code_prefix_clean,
    city_name_clean,
    state_clean,
    COUNT(*) as frequency,
    ROW_NUMBER() OVER (
      PARTITION BY zip_code_prefix_clean 
      ORDER BY COUNT(*) DESC, city_name_clean
    ) as rank_by_frequency
  FROM cleaned_geolocation
  WHERE coordinates_valid_brazil = TRUE 
    AND state_code_valid = TRUE
  GROUP BY 1, 2, 3
)

SELECT 
  g.zip_code_prefix_clean,
  g.geolocation_lat,
  g.geolocation_lng,
  g.coordinates_valid_brazil,
  
  -- Use most common city/state for this zip if coordinates are invalid
  CASE 
    WHEN g.coordinates_valid_brazil = TRUE AND g.state_code_valid = TRUE 
    THEN g.city_name_clean
    ELSE COALESCE(l.city_name_clean, g.city_name_clean)
  END as city_name_clean,
  
  CASE 
    WHEN g.coordinates_valid_brazil = TRUE AND g.state_code_valid = TRUE 
    THEN g.state_clean
    ELSE COALESCE(l.state_clean, g.state_clean)
  END as state_clean,
  
  g.state_code_valid,
  
  -- Data Quality Flags
  CASE 
    WHEN g.coordinates_valid_brazil = FALSE THEN 'Invalid coordinates for Brazil'
    WHEN g.state_code_valid = FALSE THEN 'Invalid state code'
    WHEN LENGTH(g.zip_code_prefix_clean) != 5 THEN 'Invalid zip code format'
    ELSE NULL
  END as data_quality_issue,
  
  -- Cleaning actions applied
  CASE 
    WHEN LENGTH(CAST(g.zip_code_original AS STRING)) = 4 THEN 'Padded zip code with leading zero'
    ELSE NULL
  END as cleaning_action,
  
  -- Original data for audit trail
  g.zip_code_original,
  g.city_name_original, 
  g.state_original,
  
  -- ETL metadata
  g._sdc_batched_at,
  g._loaded_at,
  CURRENT_TIMESTAMP() as cleaned_at

FROM cleaned_geolocation g
LEFT JOIN zip_city_lookup l 
  ON g.zip_code_prefix_clean = l.zip_code_prefix_clean 
  AND l.rank_by_frequency = 1
