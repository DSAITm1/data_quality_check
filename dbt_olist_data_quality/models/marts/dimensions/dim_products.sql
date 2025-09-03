{{ config(
    materialized='table',
    cluster_by=['product_category_name_english']
) }}

-- Dimension: Products
-- Grain: One row per unique product
-- Business Key: product_id
-- Source: int_products_enriched

WITH product_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY product_id) as product_sk,
        
        -- Business Key
        product_id,
        
        -- Product Attributes
        product_category_name_clean as product_category_name,
        'English translation needed' as product_category_name_english,
        
        -- Physical Dimensions
        product_name_length,
        product_description_length,
        product_photos_qty_clean as product_photos_qty,
        product_weight_g_clean as product_weight_g,
        product_length_cm_clean as product_length_cm,
        product_height_cm_clean as product_height_cm,
        product_width_cm_clean as product_width_cm,
        
        -- Calculated Dimensions
        COALESCE(product_length_cm_clean * product_height_cm_clean * product_width_cm_clean, 0) as product_volume_cm3,
        
        -- Analytics Classifications
        CASE 
            WHEN product_photos_qty_clean >= 5 THEN 'High'
            WHEN product_photos_qty_clean >= 2 THEN 'Medium'
            ELSE 'Low'
        END as photo_quality_tier,
        
        CASE 
            WHEN product_weight_g_clean >= 5000 THEN 'Heavy'
            WHEN product_weight_g_clean >= 1000 THEN 'Medium'
            WHEN product_weight_g_clean >= 100 THEN 'Light'
            ELSE 'Very Light'
        END as weight_category,
        
        CASE 
            WHEN product_category_name_clean IN ('saude_beleza', 'relogios_presentes', 'bebes', 'perfumaria') THEN 'Personal Care'
            WHEN product_category_name_clean IN ('esporte_lazer', 'brinquedos', 'livros_interesse_geral', 'musica') THEN 'Leisure & Entertainment'
            WHEN product_category_name_clean IN ('informatica_acessorios', 'eletronicos', 'telefonia', 'telefonia_fixa') THEN 'Technology'
            WHEN product_category_name_clean IN ('eletrodomesticos', 'eletrodomesticos_2', 'moveis_decoracao', 'utilidades_domesticas', 'ferramentas_jardim') THEN 'Home & Garden'
            WHEN product_category_name_clean IN ('automotivo', 'ferramentas_construcao', 'industria_comercio_e_negocios') THEN 'Industrial & Automotive'
            ELSE 'Other'
        END as category_group,
        
        -- Quality Metrics
        CASE 
            WHEN product_name_length > 0 AND product_description_length > 0 AND product_photos_qty_clean > 0 THEN 'Complete'
            WHEN product_name_length > 0 AND product_photos_qty_clean > 0 THEN 'Good'
            WHEN product_name_length > 0 THEN 'Basic'
            ELSE 'Incomplete'
        END as content_quality,
        
        -- Audit Fields
        CURRENT_TIMESTAMP() as created_at,
        'int_products_enriched' as source_model
        
    FROM {{ ref('int_products_enriched') }}
)

SELECT * FROM product_dimension
