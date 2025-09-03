{{ config(
    materialized='table',
    cluster_by=['customer_state', 'customer_city']
) }}

-- Dimension: Customers
-- Grain: One row per unique customer
-- Business Key: customer_unique_id
-- Source: int_customers_cleaned

WITH customer_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY customer_unique_id) as customer_sk,
        
        -- Business Keys
        customer_unique_id,
        customer_id,
        
        -- Customer Attributes
        customer_zip_code_prefix,
        customer_city_normalized as customer_city,
        customer_state_normalized as customer_state,
        customer_region,
        
        -- Analytics Attributes (using existing region field)
        CASE 
            WHEN customer_state_normalized IN ('SP', 'RJ') THEN 'Major Metropolitan'
            WHEN customer_state_normalized IN ('MG', 'PR', 'SC', 'RS') THEN 'Secondary Markets'
            ELSE 'Emerging Markets'
        END as market_tier,
        
        -- Audit Fields
        CURRENT_TIMESTAMP() as created_at,
        'int_customers_cleaned' as source_model
        
    FROM {{ ref('int_customers_cleaned') }}
)

SELECT * FROM customer_dimension
