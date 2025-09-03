{{ config(
    materialized='table',
    cluster_by=['seller_state', 'seller_region']
) }}

-- Dimension: Sellers
-- Grain: One row per unique seller
-- Business Key: seller_id
-- Source: int_sellers_cleaned

WITH seller_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY seller_id) as seller_sk,
        
        -- Business Key
        seller_id,
        
        -- Seller Attributes
        seller_zip_code_prefix,
        seller_city_normalized as seller_city,
        seller_state_normalized as seller_state,
        
        -- Geographic Classification
        CASE seller_state_normalized
            WHEN 'SP' THEN 'Southeast'
            WHEN 'RJ' THEN 'Southeast'
            WHEN 'ES' THEN 'Southeast'
            WHEN 'MG' THEN 'Southeast'
            WHEN 'PR' THEN 'South'
            WHEN 'SC' THEN 'South'
            WHEN 'RS' THEN 'South'
            WHEN 'GO' THEN 'Central-West'
            WHEN 'DF' THEN 'Central-West'
            WHEN 'MS' THEN 'Central-West'
            WHEN 'MT' THEN 'Central-West'
            WHEN 'BA' THEN 'Northeast'
            WHEN 'SE' THEN 'Northeast'
            WHEN 'PE' THEN 'Northeast'
            WHEN 'AL' THEN 'Northeast'
            WHEN 'PB' THEN 'Northeast'
            WHEN 'RN' THEN 'Northeast'
            WHEN 'CE' THEN 'Northeast'
            WHEN 'PI' THEN 'Northeast'
            WHEN 'MA' THEN 'Northeast'
            WHEN 'PA' THEN 'North'
            WHEN 'AP' THEN 'North'
            WHEN 'AM' THEN 'North'
            WHEN 'RR' THEN 'North'
            WHEN 'AC' THEN 'North'
            WHEN 'RO' THEN 'North'
            WHEN 'TO' THEN 'North'
            ELSE 'Unknown'
        END as seller_region,
        
        -- Business Analytics
        CASE 
            WHEN seller_state_normalized IN ('SP', 'RJ') THEN 'Tier 1 Market'
            WHEN seller_state_normalized IN ('MG', 'PR', 'SC', 'RS', 'BA') THEN 'Tier 2 Market'
            ELSE 'Tier 3 Market'
        END as market_tier,
        
        CASE 
            WHEN seller_state_normalized = 'SP' THEN 'São Paulo Hub'
            WHEN seller_state_normalized = 'RJ' THEN 'Rio de Janeiro Hub'
            WHEN seller_state_normalized IN ('MG', 'ES') THEN 'Southeast Extension'
            WHEN seller_state_normalized IN ('PR', 'SC', 'RS') THEN 'South Region'
            WHEN seller_state_normalized IN ('BA', 'PE', 'CE') THEN 'Northeast Hub'
            ELSE 'Other Regions'
        END as logistics_zone,
        
        -- Audit Fields
        CURRENT_TIMESTAMP() as created_at,
        'int_sellers_cleaned' as source_model
        
    FROM {{ ref('int_sellers_cleaned') }}
)

SELECT * FROM seller_dimension
