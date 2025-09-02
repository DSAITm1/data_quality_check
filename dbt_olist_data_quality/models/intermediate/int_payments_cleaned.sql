{{ config(materialized='table') }}

/*
    SECTION 6: Data Cleaning Implementation  
    PRIORITY 4: Payment Data Edge Cases
    
    Issue: 11 payment records (0.01%) with minor issues
    - 9 records: Invalid payment values (payment_value <= 0)
    - 2 records: Invalid installments (payment_installments < 1)
    
    Strategy: Apply business rules for edge cases
*/

WITH order_totals AS (
    SELECT 
        order_id,
        SUM(price + freight_value) as order_total_value
    FROM {{ ref('stg_order_items') }}
    GROUP BY order_id
),

payment_validation AS (
    SELECT 
        p.*,
        ot.order_total_value,
        
        -- Identify payment validation issues
        CASE 
            WHEN p.payment_value <= 0 THEN TRUE 
            ELSE FALSE 
        END as invalid_payment_value,
        
        CASE 
            WHEN p.payment_installments < 1 OR p.payment_installments IS NULL THEN TRUE 
            ELSE FALSE 
        END as invalid_installments
        
    FROM {{ ref('stg_order_payments') }} p
    LEFT JOIN order_totals ot ON p.order_id = ot.order_id
),

payments_cleaned AS (
    SELECT 
        order_id,
        payment_sequential,
        payment_type,
        
        -- Original values preserved for audit trail
        payment_value as payment_value_original,
        payment_installments as payment_installments_original,
        
        -- Apply payment correction logic (Section 6.5)
        CASE 
            -- Use order total divided by installments if payment value is invalid
            WHEN invalid_payment_value AND order_total_value > 0 AND payment_installments >= 1 
            THEN order_total_value / payment_installments
            -- Keep original if valid
            WHEN NOT invalid_payment_value THEN payment_value
            -- Set to NULL for manual review if cannot correct
            ELSE NULL
        END as payment_value_corrected,
        
        -- Apply installment correction logic (Section 6.5)
        CASE 
            -- Default to single payment if installments invalid
            WHEN invalid_installments THEN 1
            -- Keep original if valid
            ELSE payment_installments
        END as payment_installments_corrected,
        
        -- Correction metadata
        invalid_payment_value,
        invalid_installments,
        order_total_value,
        
        -- Overall payment quality assessment
        CASE 
            WHEN NOT invalid_payment_value AND NOT invalid_installments THEN 'valid_original'
            WHEN invalid_payment_value OR invalid_installments THEN 'corrected'
            ELSE 'needs_manual_review'
        END as payment_correction_status
        
    FROM payment_validation
)

SELECT 
    order_id,
    payment_sequential,
    payment_type,
    
    -- Payment values (original and corrected for Section 6.5)
    payment_value_original,
    payment_installments_original,
    payment_value_corrected,
    payment_installments_corrected,
    
    -- Data quality metadata
    invalid_payment_value,
    invalid_installments,
    payment_correction_status,
    order_total_value,
    
    -- Section 6 audit trail
    CURRENT_TIMESTAMP() as cleaned_timestamp,
    'section_6_payment_cleanup_v1' as cleaning_version

FROM payments_cleaned
ORDER BY payment_correction_status DESC, order_id, payment_sequential
