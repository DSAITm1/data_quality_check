{{ config(materialized='table') }}

-- Referential Integrity Analysis: Check relationships between tables
WITH referential_checks AS (
  
  -- Check Orders -> Customers relationship
  SELECT 
    'orders_to_customers' as relationship_name,
    'orders' as parent_table,
    'customers' as child_table,
    'customer_id' as key_column,
    COUNT(DISTINCT o.customer_id) as distinct_keys_in_parent,
    COUNT(DISTINCT c.customer_id) as distinct_keys_in_child,
    COUNT(DISTINCT o.customer_id) - COUNT(DISTINCT CASE WHEN c.customer_id IS NOT NULL THEN o.customer_id END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN c.customer_id IS NOT NULL THEN o.customer_id END), COUNT(DISTINCT o.customer_id)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_orders') }} o
  LEFT JOIN {{ ref('stg_customers') }} c ON o.customer_id = c.customer_id
  
  UNION ALL
  
  -- Check Order Items -> Orders relationship
  SELECT 
    'order_items_to_orders' as relationship_name,
    'order_items' as parent_table,
    'orders' as child_table,
    'order_id' as key_column,
    COUNT(DISTINCT oi.order_id) as distinct_keys_in_parent,
    COUNT(DISTINCT o.order_id) as distinct_keys_in_child,
    COUNT(DISTINCT oi.order_id) - COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN oi.order_id END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN oi.order_id END), COUNT(DISTINCT oi.order_id)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_order_items') }} oi
  LEFT JOIN {{ ref('stg_orders') }} o ON oi.order_id = o.order_id
  
  UNION ALL
  
  -- Check Order Items -> Products relationship
  SELECT 
    'order_items_to_products' as relationship_name,
    'order_items' as parent_table,
    'products' as child_table,
    'product_id' as key_column,
    COUNT(DISTINCT oi.product_id) as distinct_keys_in_parent,
    COUNT(DISTINCT p.product_id) as distinct_keys_in_child,
    COUNT(DISTINCT oi.product_id) - COUNT(DISTINCT CASE WHEN p.product_id IS NOT NULL THEN oi.product_id END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN p.product_id IS NOT NULL THEN oi.product_id END), COUNT(DISTINCT oi.product_id)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_order_items') }} oi
  LEFT JOIN {{ ref('stg_products') }} p ON oi.product_id = p.product_id
  
  UNION ALL
  
  -- Check Order Items -> Sellers relationship
  SELECT 
    'order_items_to_sellers' as relationship_name,
    'order_items' as parent_table,
    'sellers' as child_table,
    'seller_id' as key_column,
    COUNT(DISTINCT oi.seller_id) as distinct_keys_in_parent,
    COUNT(DISTINCT s.seller_id) as distinct_keys_in_child,
    COUNT(DISTINCT oi.seller_id) - COUNT(DISTINCT CASE WHEN s.seller_id IS NOT NULL THEN oi.seller_id END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN s.seller_id IS NOT NULL THEN oi.seller_id END), COUNT(DISTINCT oi.seller_id)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_order_items') }} oi
  LEFT JOIN {{ ref('stg_sellers') }} s ON oi.seller_id = s.seller_id
  
  UNION ALL
  
  -- Check Order Payments -> Orders relationship
  SELECT 
    'order_payments_to_orders' as relationship_name,
    'order_payments' as parent_table,
    'orders' as child_table,
    'order_id' as key_column,
    COUNT(DISTINCT op.order_id) as distinct_keys_in_parent,
    COUNT(DISTINCT o.order_id) as distinct_keys_in_child,
    COUNT(DISTINCT op.order_id) - COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN op.order_id END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN op.order_id END), COUNT(DISTINCT op.order_id)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_order_payments') }} op
  LEFT JOIN {{ ref('stg_orders') }} o ON op.order_id = o.order_id
  
  UNION ALL
  
  -- Check Order Reviews -> Orders relationship
  SELECT 
    'order_reviews_to_orders' as relationship_name,
    'order_reviews' as parent_table,
    'orders' as child_table,
    'order_id' as key_column,
    COUNT(DISTINCT orv.order_id) as distinct_keys_in_parent,
    COUNT(DISTINCT o.order_id) as distinct_keys_in_child,
    COUNT(DISTINCT orv.order_id) - COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN orv.order_id END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN o.order_id IS NOT NULL THEN orv.order_id END), COUNT(DISTINCT orv.order_id)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_order_reviews') }} orv
  LEFT JOIN {{ ref('stg_orders') }} o ON orv.order_id = o.order_id
  
  UNION ALL
  
  -- Check Products -> Category Translations relationship (optional reference)
  SELECT 
    'products_to_category_translations' as relationship_name,
    'products' as parent_table,
    'category_translations' as child_table,
    'product_category_name' as key_column,
    COUNT(DISTINCT p.product_category_name) as distinct_keys_in_parent,
    COUNT(DISTINCT ct.product_category_name) as distinct_keys_in_child,
    COUNT(DISTINCT p.product_category_name) - COUNT(DISTINCT CASE WHEN ct.product_category_name IS NOT NULL THEN p.product_category_name END) as orphaned_records,
    ROUND(SAFE_DIVIDE(COUNT(DISTINCT CASE WHEN ct.product_category_name IS NOT NULL THEN p.product_category_name END), COUNT(DISTINCT p.product_category_name)) * 100, 2) as referential_integrity_percentage
  FROM {{ ref('stg_products') }} p
  LEFT JOIN {{ ref('stg_category_translations') }} ct ON p.product_category_name = ct.product_category_name
)

SELECT 
  relationship_name,
  parent_table,
  child_table, 
  key_column,
  distinct_keys_in_parent,
  distinct_keys_in_child,
  orphaned_records,
  referential_integrity_percentage,
  CASE 
    WHEN referential_integrity_percentage = 100 THEN 'PERFECT'
    WHEN referential_integrity_percentage >= 95 THEN 'EXCELLENT' 
    WHEN referential_integrity_percentage >= 90 THEN 'GOOD'
    WHEN referential_integrity_percentage >= 80 THEN 'FAIR'
    ELSE 'POOR'
  END as integrity_rating
FROM referential_checks
ORDER BY referential_integrity_percentage DESC
