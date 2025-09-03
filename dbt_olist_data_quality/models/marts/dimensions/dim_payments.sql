{{ config(
    materialized='table',
    cluster_by=['payment_type']
) }}

-- Dimension: Payments
-- Grain: One row per unique payment record
-- Business Key: order_id + payment_sequential
-- Source: int_payments_cleaned

WITH payment_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY order_id, payment_sequential) as payment_sk,
        
        -- Business Keys
        order_id,
        payment_sequential,
        
        -- Payment Attributes
        payment_type,
        
        -- Payment Analytics Attributes
        CASE 
            WHEN payment_type = 'CREDIT_CARD' THEN 'Digital Payment'
            WHEN payment_type = 'DEBIT_CARD' THEN 'Digital Payment'
            WHEN payment_type = 'BOLETO' THEN 'Bank Transfer'
            WHEN payment_type = 'VOUCHER' THEN 'Promotional Payment'
            ELSE 'Other Payment'
        END as payment_category,
        
        CASE 
            WHEN payment_type IN ('CREDIT_CARD', 'DEBIT_CARD') THEN 'Instant'
            WHEN payment_type = 'BOLETO' THEN 'Delayed'
            WHEN payment_type = 'VOUCHER' THEN 'Instant'
            ELSE 'Unknown'
        END as payment_processing_type,
        
        -- Data lineage
        CURRENT_TIMESTAMP() as created_at,
        'int_payments_cleaned' as source_model
        
    FROM {{ ref('int_payments_cleaned') }}
    WHERE payment_value_corrected > 0  -- Only valid payments
)

SELECT * FROM payment_dimension
