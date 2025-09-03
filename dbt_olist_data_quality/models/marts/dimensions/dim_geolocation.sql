{{ config(
    materialized='table',
    cluster_by=['geolocation_state', 'confidence_level']
) }}

-- Dimension: Geolocation
-- Grain: One row per unique zip code prefix
-- Business Key: geolocation_zip_code_prefix
-- Source: int_geolocation_consolidated

WITH geolocation_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY geolocation_zip_code_prefix) as geolocation_sk,
        
        -- Business Key
        geolocation_zip_code_prefix,
        
        -- Geographic Attributes
        geolocation_city_normalized as geolocation_city,
        geolocation_state,
        consolidated_lat as geolocation_lat,
        consolidated_lng as geolocation_lng,
        coordinate_confidence as confidence_level,
        
        -- Regional Classification
        CASE geolocation_state
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
        END as region,
        
        -- Delivery Analytics
        CASE 
            WHEN geolocation_state IN ('SP', 'RJ') THEN 'Express Delivery Zone'
            WHEN geolocation_state IN ('MG', 'PR', 'SC', 'RS') THEN 'Fast Delivery Zone'
            ELSE 'Standard Delivery Zone'
        END as delivery_zone,
        
        -- Geographic Analytics
        CASE
            WHEN consolidated_lat BETWEEN -23.5 AND -22.5 AND consolidated_lng BETWEEN -47.5 AND -46.0 THEN 'São Paulo Metropolitan'
            WHEN consolidated_lat BETWEEN -23.0 AND -22.7 AND consolidated_lng BETWEEN -43.8 AND -43.1 THEN 'Rio de Janeiro Metropolitan'
            WHEN consolidated_lat BETWEEN -20.0 AND -19.7 AND consolidated_lng BETWEEN -44.2 AND -43.7 THEN 'Belo Horizonte Metropolitan'
            ELSE 'Other Areas'
        END as metropolitan_area,
        
        -- Quality Indicators
        CASE coordinate_confidence
            WHEN 'high' THEN 'Exact Coordinates'
            WHEN 'medium' THEN 'City Estimated'
            WHEN 'low' THEN 'State Estimated'
            ELSE 'Unknown Quality'
        END as coordinate_quality,
        
        -- Audit Fields
        CURRENT_TIMESTAMP() as created_at,
        'int_geolocation_consolidated' as source_model
        
    FROM {{ ref('int_geolocation_consolidated') }}
)

SELECT * FROM geolocation_dimension
