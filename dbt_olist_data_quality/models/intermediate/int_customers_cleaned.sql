{{ config(materialized='table') }}

/*
    SECTION 6: Data Cleaning Implementation
    PRIORITY 1: Customer Data Deduplication & Brazilian Text Normalization
    
    Issue: 3,345 duplicate customer_unique_id records affecting 3.4% of customers
    Strategy: Master Record Selection - Select ONE master customer_id per customer_unique_id group
    
    Selection Criteria (priority order):
    1. Most recent activity (latest order date)
    2. Most complete data (fewest NULL geographic fields)
    3. Highest order value
    4. Lexicographically first customer_id if still tied
*/

WITH customer_order_stats AS (
    SELECT 
        c.customer_id,
        c.customer_unique_id,
        MAX(o.order_approved_at) as last_order_date,
        COUNT(o.order_id) as total_orders,
        SUM(COALESCE(oi.price, 0) + COALESCE(oi.freight_value, 0)) as total_order_value
    FROM {{ ref('stg_customers') }} c
    LEFT JOIN {{ ref('stg_orders') }} o ON c.customer_id = o.customer_id
    LEFT JOIN {{ ref('stg_order_items') }} oi ON o.order_id = oi.order_id
    GROUP BY c.customer_id, c.customer_unique_id
),

customer_completeness AS (
    SELECT 
        customer_id,
        customer_unique_id,
        -- Count non-NULL geographic fields for completeness score
        (CASE WHEN customer_zip_code_prefix IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN customer_city_original IS NOT NULL THEN 1 ELSE 0 END +
         CASE WHEN customer_state IS NOT NULL THEN 1 ELSE 0 END) as complete_fields_count
    FROM {{ ref('stg_customers') }}
),

customer_master_selection AS (
    SELECT 
        c.*,
        cos.last_order_date,
        COALESCE(cos.total_orders, 0) as total_orders,
        COALESCE(cos.total_order_value, 0) as total_order_value,
        cc.complete_fields_count,
        -- Master customer selection logic (Section 6.2)
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY 
                cos.last_order_date DESC NULLS LAST,
                cc.complete_fields_count DESC,
                cos.total_order_value DESC NULLS LAST,
                c.customer_id ASC
        ) as master_rank
    FROM {{ ref('stg_customers') }} c
    LEFT JOIN customer_order_stats cos ON c.customer_id = cos.customer_id
    LEFT JOIN customer_completeness cc ON c.customer_id = cc.customer_id
),

-- Brazilian text normalization (Section 6.3)
customers_cleaned AS (
    SELECT 
        customer_id,
        customer_unique_id,
        
        -- Original fields preserved for audit trail
        customer_zip_code_prefix,
        customer_city_original,
        customer_state as customer_state_original,
        
        -- Normalized geographic fields using Brazilian text cleaning rules
        TRIM(REGEXP_REPLACE(
            INITCAP(LOWER(COALESCE(customer_city_original, ''))), 
            r'\s+', ' '
        )) as customer_city_normalized,
        
        TRIM(REGEXP_REPLACE(
            UPPER(COALESCE(customer_state, '')), 
            r'\s+', ' '
        )) as customer_state_normalized,
        
        -- Master customer metadata
        last_order_date,
        total_orders,
        total_order_value,
        complete_fields_count,
        master_rank,
        
        -- Deduplication flags
        CASE WHEN master_rank = 1 THEN TRUE ELSE FALSE END as is_master_customer,
        COUNT(*) OVER (PARTITION BY customer_unique_id) as duplicate_count,
        
        -- Brazilian region mapping
        CASE 
            WHEN UPPER(customer_state) IN ('AC', 'AM', 'AP', 'PA', 'RO', 'RR', 'TO') THEN 'North'
            WHEN UPPER(customer_state) IN ('AL', 'BA', 'CE', 'MA', 'PB', 'PE', 'PI', 'RN', 'SE') THEN 'Northeast'  
            WHEN UPPER(customer_state) IN ('DF', 'GO', 'MT', 'MS') THEN 'Central-West'
            WHEN UPPER(customer_state) IN ('ES', 'MG', 'RJ', 'SP') THEN 'Southeast'
            WHEN UPPER(customer_state) IN ('PR', 'RS', 'SC') THEN 'South'
            ELSE 'Unknown'
        END as customer_region
        
    FROM customer_master_selection
)

SELECT 
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    
    -- Geographic fields (original and normalized for Section 6.3)
    customer_city_original,
    customer_state_original,
    customer_city_normalized,
    customer_state_normalized,
    customer_region,
    
    -- Order statistics for master selection
    total_orders,
    total_order_value,
    last_order_date,
    
    -- Data quality metadata (Section 6.2)
    complete_fields_count,
    is_master_customer,
    duplicate_count,
    
    -- Section 6 audit trail
    CURRENT_TIMESTAMP() as cleaned_timestamp,
    'section_6_deduplication_v1' as cleaning_version

FROM customers_cleaned
ORDER BY customer_unique_id, master_rank
