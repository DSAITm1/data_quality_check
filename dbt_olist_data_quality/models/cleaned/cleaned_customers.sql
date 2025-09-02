{{ config(materialized='table') }}

-- Clean Customer Data: Standardize zip codes, normalize addresses, validate against geolocation
WITH cleaned_customers AS (
  SELECT 
    customer_id,
    customer_unique_id,
    
    -- Standardize zip code: pad with leading zeros if needed
    CASE 
      WHEN LENGTH(CAST(customer_zip_code_prefix AS STRING)) = 4 
      THEN CONCAT('0', CAST(customer_zip_code_prefix AS STRING))
      ELSE CAST(customer_zip_code_prefix AS STRING)
    END as zip_code_prefix_clean,
    
    -- Clean city name: normalize case, remove accents
    TRIM(LOWER(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(
            REGEXP_REPLACE(
              REGEXP_REPLACE(customer_city, r'[áàâã]', 'a'),
              r'[éèê]', 'e'),
            r'[íìî]', 'i'),
          r'[óòôõ]', 'o'),
        r'[úùû]', 'u')
    )) as city_name_clean,
    
    -- Clean state: ensure uppercase, validate
    UPPER(TRIM(customer_state)) as state_clean,
    
    -- Validate state codes
    CASE 
      WHEN UPPER(TRIM(customer_state)) IN (
        'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 
        'MT', 'MS', 'MG', 'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 
        'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO'
      ) 
      THEN TRUE 
      ELSE FALSE 
    END as state_code_valid,
    
    -- Original data for reference
    customer_zip_code_prefix as zip_code_original,
    customer_city as city_name_original,
    customer_state as state_original,
    
    -- ETL metadata  
    _sdc_batched_at,
    _loaded_at
    
  FROM {{ ref('stg_customers') }}
)

SELECT 
  c.customer_id,
  c.customer_unique_id,
  c.zip_code_prefix_clean,
  c.city_name_clean,
  c.state_clean,
  c.state_code_valid,
  
  -- Cross-validate with cleaned geolocation data
  CASE 
    WHEN g.zip_code_prefix_clean IS NOT NULL THEN TRUE
    ELSE FALSE
  END as zip_code_exists_in_geolocation,
  
  -- Check if customer city/state matches geolocation for same zip
  CASE 
    WHEN g.zip_code_prefix_clean IS NOT NULL 
         AND c.city_name_clean = g.city_name_clean 
         AND c.state_clean = g.state_clean 
    THEN TRUE
    WHEN g.zip_code_prefix_clean IS NOT NULL THEN FALSE
    ELSE NULL
  END as location_matches_geolocation,
  
  -- Suggested corrections from geolocation data
  g.city_name_clean as suggested_city_from_geolocation,
  g.state_clean as suggested_state_from_geolocation,
  
  -- Data Quality Assessment
  CASE 
    WHEN c.state_code_valid = FALSE THEN 'Invalid state code'
    WHEN LENGTH(c.zip_code_prefix_clean) != 5 THEN 'Invalid zip code format'
    WHEN g.zip_code_prefix_clean IS NULL THEN 'Zip code not found in geolocation data'
    WHEN c.city_name_clean != g.city_name_clean OR c.state_clean != g.state_clean 
    THEN 'City/State mismatch with geolocation data'
    ELSE NULL
  END as data_quality_issue,
  
  -- Cleaning actions applied
  CASE 
    WHEN LENGTH(CAST(c.zip_code_original AS STRING)) = 4 THEN 'Padded zip code with leading zero'
    ELSE NULL
  END as cleaning_action,
  
  -- Original data for audit trail
  c.zip_code_original,
  c.city_name_original,
  c.state_original,
  
  -- ETL metadata
  c._sdc_batched_at,
  c._loaded_at,
  CURRENT_TIMESTAMP() as cleaned_at

FROM cleaned_customers c
LEFT JOIN {{ ref('cleaned_geolocation') }} g 
  ON c.zip_code_prefix_clean = g.zip_code_prefix_clean
  AND g.coordinates_valid_brazil = TRUE  -- Only join with valid geolocation records
