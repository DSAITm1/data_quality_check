{{ config(materialized='table') }}

/*
    SECTION 6: Data Cleaning Implementation
    PRIORITY 2: Brazilian Text Normalization for Sellers
    
    Scope: Standardize seller city/state names for consistency
    Finding: 95% quality score - only text normalization needed
*/

WITH sellers_cleaned AS (
    SELECT 
        seller_id,
        seller_zip_code_prefix,
        
        -- Original fields preserved for audit trail
        seller_city_original,
        seller_state as seller_state_original,
        
        -- Normalized geographic fields using Brazilian text cleaning rules (Section 6.3)
        TRIM(REGEXP_REPLACE(
            INITCAP(LOWER(COALESCE(seller_city_normalized, ''))), 
            r'\s+', ' '
        )) as seller_city_clean,
        
        -- Brazilian region mapping for sellers
        CASE 
            WHEN UPPER(seller_state) IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'North'
            WHEN UPPER(seller_state) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Northeast'  
            WHEN UPPER(seller_state) IN ('DF', 'GO', 'MT', 'MS') THEN 'Central-West'
            WHEN UPPER(seller_state) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Southeast'
            WHEN UPPER(seller_state) IN ('PR', 'RS', 'SC') THEN 'South'
            ELSE 'Unknown'
        END as seller_region
        
    FROM {{ ref('stg_sellers') }}
)

SELECT 
    seller_id,
    seller_zip_code_prefix,
    
    -- Geographic fields (original and normalized for Section 6.3)
    seller_city_original,
    seller_state_original,
    seller_city_clean as seller_city_normalized,
    seller_state_original as seller_state_normalized,
    seller_region,
    
    -- Section 6 audit trail
    CURRENT_TIMESTAMP() as cleaned_timestamp,
    'section_6_text_normalization_v1' as cleaning_version

FROM sellers_cleaned
ORDER BY seller_region, seller_state_normalized, seller_city_normalized
