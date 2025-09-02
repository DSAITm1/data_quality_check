{{ config(materialized='view') }}

-- Intermediate Products: Clean and standardize product data with category enrichment
WITH cleaned_products AS (
  SELECT 
    product_id,
    
    -- Clean and standardize category name
    TRIM(LOWER(product_category_name)) as product_category_name_clean,
    
    -- Handle missing values and outliers in dimensions
    CASE 
      WHEN product_weight_g IS NULL OR product_weight_g <= 0 THEN NULL
      WHEN product_weight_g > 40000 THEN 40000  -- Cap at 40kg (reasonable max for e-commerce)
      ELSE product_weight_g
    END as product_weight_g_clean,
    
    CASE 
      WHEN product_length_cm IS NULL OR product_length_cm <= 0 THEN NULL
      WHEN product_length_cm > 200 THEN 200  -- Cap at 2m
      ELSE product_length_cm
    END as product_length_cm_clean,
    
    CASE 
      WHEN product_height_cm IS NULL OR product_height_cm <= 0 THEN NULL
      WHEN product_height_cm > 200 THEN 200  -- Cap at 2m
      ELSE product_height_cm
    END as product_height_cm_clean,
    
    CASE 
      WHEN product_width_cm IS NULL OR product_width_cm <= 0 THEN NULL
      WHEN product_width_cm > 200 THEN 200  -- Cap at 2m
      ELSE product_width_cm
    END as product_width_cm_clean,
    
    -- Clean photo quantity
    CASE 
      WHEN product_photos_qty IS NULL OR product_photos_qty < 0 THEN 0
      WHEN product_photos_qty > 20 THEN 20  -- Cap at 20 photos
      ELSE product_photos_qty
    END as product_photos_qty_clean,
    
    -- Original values for reference
    product_category_name as product_category_name_original,
    product_name_length,
    product_description_length,
    product_weight_g as product_weight_g_original,
    product_length_cm as product_length_cm_original,
    product_height_cm as product_height_cm_original,
    product_width_cm as product_width_cm_original,
    product_photos_qty as product_photos_qty_original,
    
    -- Data quality flags from staging
    valid_weight,
    valid_length,
    valid_height,
    valid_width,
    valid_photos_qty
  FROM {{ ref('stg_products') }}
),

-- Add derived fields and business logic
enriched_products AS (
  SELECT 
    *,
    
    -- Calculate volume (cubic cm)
    CASE 
      WHEN product_length_cm_clean IS NOT NULL 
        AND product_height_cm_clean IS NOT NULL 
        AND product_width_cm_clean IS NOT NULL
      THEN product_length_cm_clean * product_height_cm_clean * product_width_cm_clean
      ELSE NULL
    END as product_volume_cubic_cm
  FROM cleaned_products
),

-- Add categorization based on calculated fields
final_products AS (
  SELECT 
    *,
    
    -- Weight categories
    CASE 
      WHEN product_weight_g_clean IS NULL THEN 'Unknown'
      WHEN product_weight_g_clean <= 100 THEN 'Very Light'
      WHEN product_weight_g_clean <= 500 THEN 'Light'
      WHEN product_weight_g_clean <= 1000 THEN 'Medium'
      WHEN product_weight_g_clean <= 5000 THEN 'Heavy'
      ELSE 'Very Heavy'
    END as weight_category,
    
    -- Size categories based on volume
    CASE 
      WHEN product_volume_cubic_cm IS NULL THEN 'Unknown'
      WHEN product_volume_cubic_cm <= 1000 THEN 'Very Small'
      WHEN product_volume_cubic_cm <= 10000 THEN 'Small'
      WHEN product_volume_cubic_cm <= 100000 THEN 'Medium'
      WHEN product_volume_cubic_cm <= 1000000 THEN 'Large'
      ELSE 'Very Large'
    END as size_category,
    
    -- Photo richness indicator
    CASE 
      WHEN product_photos_qty_clean = 0 THEN 'No Photos'
      WHEN product_photos_qty_clean <= 2 THEN 'Few Photos'
      WHEN product_photos_qty_clean <= 5 THEN 'Good Photos'
      ELSE 'Rich Photos'
    END as photo_richness,
    
    -- Data quality score (using available validation flags from staging)
    CASE 
      WHEN product_id IS NOT NULL AND product_category_name_clean IS NOT NULL 
        AND (COALESCE(valid_weight, 1) + COALESCE(valid_length, 1) + COALESCE(valid_height, 1) + COALESCE(valid_width, 1)) = 4 THEN 'High'
      WHEN product_id IS NOT NULL AND product_category_name_clean IS NOT NULL THEN 'Medium'
      ELSE 'Low'
    END as data_quality_level
  FROM enriched_products
)

SELECT * FROM final_products
