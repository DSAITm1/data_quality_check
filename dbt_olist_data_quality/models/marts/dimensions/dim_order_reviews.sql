{{ config(
    materialized='table',
    cluster_by=['review_score', 'order_id']
) }}

-- Dimension: Order Reviews
-- Grain: One row per unique review
-- Business Key: review_id
-- Source: stg_order_reviews

WITH review_dimension AS (
    SELECT 
        -- Surrogate Key Generation
        ROW_NUMBER() OVER (ORDER BY review_id) as review_sk,
        
        -- Business Keys
        review_id,
        order_id,
        
        -- Review Attributes
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        
        -- Review Analytics Attributes
        CASE 
            WHEN review_score >= 4 THEN 'Positive'
            WHEN review_score = 3 THEN 'Neutral'
            WHEN review_score <= 2 THEN 'Negative'
            ELSE 'Unknown'
        END as review_sentiment,
        
        CASE 
            WHEN review_score = 5 THEN 'Excellent'
            WHEN review_score = 4 THEN 'Good'
            WHEN review_score = 3 THEN 'Average'
            WHEN review_score = 2 THEN 'Poor'
            WHEN review_score = 1 THEN 'Terrible'
            ELSE 'No Rating'
        END as review_category,
        
        -- Comment Analysis
        CASE 
            WHEN review_comment_title IS NOT NULL OR review_comment_message IS NOT NULL THEN 'Has Comments'
            ELSE 'Score Only'
        END as comment_type,
        
        CASE 
            WHEN review_answer_timestamp IS NOT NULL THEN 'Answered'
            ELSE 'Not Answered'
        END as response_status,
        
        -- Review Quality Metrics
        CASE 
            WHEN LENGTH(COALESCE(review_comment_message, '')) > 50 THEN 'Detailed'
            WHEN LENGTH(COALESCE(review_comment_message, '')) > 10 THEN 'Brief'
            ELSE 'Minimal'
        END as comment_detail_level,
        
        -- Data lineage
        CURRENT_TIMESTAMP() as created_at,
        'stg_order_reviews' as source_model
        
    FROM {{ ref('stg_order_reviews') }}
    WHERE valid_review_score = 1  -- Only valid review scores
)

SELECT * FROM review_dimension
