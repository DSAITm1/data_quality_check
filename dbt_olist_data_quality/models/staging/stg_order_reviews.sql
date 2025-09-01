{{ config(materialized='view') }}

with source_data as (
    select 
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    from {{ source('olist_raw', 'order_reviews') }}
),

cleaned_data as (
    select 
        review_id,
        order_id,
        CAST(review_score as INT64) as review_score,
        review_comment_title,
        review_comment_message,
        -- Parse timestamps
        review_creation_date,
        review_answer_timestamp,
        -- Validation flags
        CASE WHEN CAST(review_score as INT64) BETWEEN 1 AND 5 THEN 1 ELSE 0 END as valid_review_score,
        CASE 
            WHEN review_answer_timestamp >= review_creation_date OR review_answer_timestamp IS NULL THEN 1 
            ELSE 0 
        END as valid_answer_sequence,
        -- Text length validation
        LENGTH(review_comment_title) as title_length,
        LENGTH(review_comment_message) as message_length
    from source_data
    where order_id is not null
)

select * from cleaned_data
