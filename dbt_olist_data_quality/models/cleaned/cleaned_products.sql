{{ config(materialized='table') }}

-- Clean Product Data: Standardize categories, validate dimensions, apply translations
WITH cleaned_products AS (
  SELECT 
    product_id,
    
    -- Clean category name: normalize case, remove extra spaces
    TRIM(LOWER(product_category_name)) as product_category_clean,
    
    -- Product dimensions with validation
    CASE 
      WHEN product_weight_g IS NOT NULL AND product_weight_g > 0 AND product_weight_g <= 50000 
      THEN product_weight_g 
      ELSE NULL 
    END as weight_g_clean,
    
    CASE 
      WHEN product_length_cm IS NOT NULL AND product_length_cm > 0 AND product_length_cm <= 200 
      THEN product_length_cm 
      ELSE NULL 
    END as length_cm_clean,
    
    CASE 
      WHEN product_height_cm IS NOT NULL AND product_height_cm > 0 AND product_height_cm <= 200 
      THEN product_height_cm 
      ELSE NULL 
    END as height_cm_clean,
    
    CASE 
      WHEN product_width_cm IS NOT NULL AND product_width_cm > 0 AND product_width_cm <= 200 
      THEN product_width_cm 
      ELSE NULL 
    END as width_cm_clean,
    
    CASE 
      WHEN product_photos_qty IS NOT NULL AND product_photos_qty >= 0 AND product_photos_qty <= 20 
      THEN product_photos_qty 
      ELSE NULL 
    END as photos_qty_clean,
    
    -- Text fields with length validation
    CASE 
      WHEN product_name_lenght IS NOT NULL AND product_name_lenght > 0 AND product_name_lenght <= 500 
      THEN product_name_lenght 
      ELSE NULL 
    END as name_length_clean,
    
    CASE 
      WHEN product_description_lenght IS NOT NULL AND product_description_lenght > 0 AND product_description_lenght <= 5000 
      THEN product_description_lenght 
      ELSE NULL 
    END as description_length_clean,
    
    -- Original values for reference
    product_category_name as category_original,
    product_weight_g as weight_original,
    product_length_cm as length_original,
    product_height_cm as height_original,
    product_width_cm as width_original,
    product_photos_qty as photos_qty_original,
    product_name_lenght as name_length_original,
    product_description_lenght as description_length_original,
    
    -- ETL metadata
    _sdc_batched_at,
    _loaded_at
    
  FROM {{ ref('stg_products') }}
),

product_enrichment AS (
  SELECT 
    p.*,
    
    -- Add English category translation
    ct.product_category_name_english as category_english,
    
    -- Calculate volume if all dimensions available
    CASE 
      WHEN p.length_cm_clean IS NOT NULL 
           AND p.height_cm_clean IS NOT NULL 
           AND p.width_cm_clean IS NOT NULL 
      THEN p.length_cm_clean * p.height_cm_clean * p.width_cm_clean 
      ELSE NULL 
    END as volume_cm3,
    
    -- Dimension validation flags
    CASE 
      WHEN p.weight_original IS NOT NULL AND p.weight_g_clean IS NULL THEN TRUE
      ELSE FALSE
    END as weight_outlier_removed,
    
    CASE 
      WHEN p.length_original IS NOT NULL AND p.length_cm_clean IS NULL THEN TRUE
      WHEN p.height_original IS NOT NULL AND p.height_cm_clean IS NULL THEN TRUE
      WHEN p.width_original IS NOT NULL AND p.width_cm_clean IS NULL THEN TRUE
      ELSE FALSE
    END as dimension_outlier_removed,
    
    -- Category validation
    CASE 
      WHEN ct.product_category_name_english IS NOT NULL THEN TRUE
      ELSE FALSE
    END as category_has_translation
    
  FROM cleaned_products p
  LEFT JOIN {{ ref('stg_category_translations') }} ct 
    ON p.product_category_clean = ct.product_category_name
)

SELECT 
  product_id,
  product_category_clean,
  category_english,
  category_has_translation,
  
  -- Cleaned dimensions
  weight_g_clean,
  length_cm_clean,
  height_cm_clean,
  width_cm_clean,
  volume_cm3,
  photos_qty_clean,
  name_length_clean,
  description_length_clean,
  
  -- Data quality flags
  weight_outlier_removed,
  dimension_outlier_removed,
  
  -- Completeness metrics
  CASE 
    WHEN weight_g_clean IS NOT NULL 
         AND length_cm_clean IS NOT NULL 
         AND height_cm_clean IS NOT NULL 
         AND width_cm_clean IS NOT NULL 
    THEN 'Complete'
    WHEN weight_g_clean IS NOT NULL OR length_cm_clean IS NOT NULL 
    THEN 'Partial'
    ELSE 'Missing'
  END as dimension_completeness,
  
  -- Data quality assessment
  CASE 
    WHEN product_category_clean IS NULL THEN 'Missing category'
    WHEN NOT category_has_translation THEN 'Category missing translation'
    WHEN weight_outlier_removed THEN 'Weight outlier removed'
    WHEN dimension_outlier_removed THEN 'Dimension outlier removed'
    ELSE NULL
  END as data_quality_issue,
  
  -- Cleaning actions applied
  CASE 
    WHEN weight_outlier_removed AND dimension_outlier_removed THEN 'Removed invalid weight; Removed invalid dimensions'
    WHEN weight_outlier_removed THEN 'Removed invalid weight'
    WHEN dimension_outlier_removed THEN 'Removed invalid dimensions'
    ELSE NULL
  END as cleaning_actions,
  
  -- Original data for audit trail
  category_original,
  weight_original,
  length_original,
  height_original,
  width_original,
  photos_qty_original,
  name_length_original,
  description_length_original,
  
  -- ETL metadata
  _sdc_batched_at,
  _loaded_at,
  CURRENT_TIMESTAMP() as cleaned_at

FROM product_enrichment
