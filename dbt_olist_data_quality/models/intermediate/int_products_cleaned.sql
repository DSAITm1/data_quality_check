{{ config(materialized='table') }}

/*
    SECTION 6: Data Cleaning Implementation  
    PRIORITY 2: Brazilian Text Normalization for Products
    
    Scope: Standardize product category names and text fields
    Finding: 99.1% quality score - only text normalization needed
*/

WITH products_cleaned AS (
    SELECT 
        product_id,
        
        -- Original fields preserved for audit trail
        product_category_name as product_category_name_original,
        product_name_length,
        product_description_length,  
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm,
        
        -- Normalized category name using Brazilian text cleaning rules (Section 6.3)
        CASE 
            WHEN product_category_name IS NULL THEN 'uncategorized'
            ELSE TRIM(REGEXP_REPLACE(
                INITCAP(LOWER(product_category_name)), 
                r'\s+', ' '
            ))
        END as product_category_normalized,
        
        -- Product size category for analytics
        CASE 
            WHEN product_weight_g IS NULL OR product_length_cm IS NULL 
                OR product_height_cm IS NULL OR product_width_cm IS NULL THEN 'unknown'
            WHEN product_weight_g <= 100 AND product_length_cm <= 20 
                AND product_height_cm <= 10 AND product_width_cm <= 15 THEN 'small'
            WHEN product_weight_g <= 1000 AND product_length_cm <= 50 
                AND product_height_cm <= 30 AND product_width_cm <= 40 THEN 'medium' 
            WHEN product_weight_g <= 5000 AND product_length_cm <= 100 
                AND product_height_cm <= 60 AND product_width_cm <= 80 THEN 'large'
            ELSE 'extra_large'
        END as product_size_category,
        
        -- Product description quality score
        CASE 
            WHEN product_name_length IS NULL AND product_description_length IS NULL THEN 'no_description'
            WHEN COALESCE(product_name_length, 0) + COALESCE(product_description_length, 0) < 50 THEN 'poor'
            WHEN COALESCE(product_name_length, 0) + COALESCE(product_description_length, 0) < 200 THEN 'good'
            ELSE 'excellent'
        END as description_quality
        
    FROM {{ ref('stg_products') }}
)

SELECT 
    product_id,
    
    -- Product details
    product_category_name_original,
    product_category_normalized,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    
    -- Derived analytics fields  
    product_size_category,
    description_quality,
    
    -- Section 6 audit trail
    CURRENT_TIMESTAMP() as cleaned_timestamp,
    'section_6_text_normalization_v1' as cleaning_version

FROM products_cleaned
ORDER BY product_category_normalized, product_size_category
