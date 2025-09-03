{{ config(
    materialized='table',
    cluster_by=['year', 'quarter']
) }}

-- Dimension: Date
-- Grain: One row per date
-- Business Key: date_key (YYYYMMDD format)
-- Source: Generated date dimension

WITH date_spine AS (
    -- Generate dates from 2016 to 2020 (covering the dataset period)
    SELECT 
        date_val
    FROM UNNEST(GENERATE_DATE_ARRAY('2016-01-01', '2020-12-31', INTERVAL 1 DAY)) AS date_val
),

date_dimension AS (
    SELECT 
        -- Surrogate Key (same as business key for dates)
        CAST(FORMAT_DATE('%Y%m%d', date_val) AS INT64) as date_sk,
        
        -- Business Key
        CAST(FORMAT_DATE('%Y%m%d', date_val) AS INT64) as date_key,
        
        -- Date Attributes
        date_val as full_date,
        
        -- Year Attributes
        EXTRACT(YEAR FROM date_val) as year,
        EXTRACT(QUARTER FROM date_val) as quarter,
        EXTRACT(MONTH FROM date_val) as month,
        EXTRACT(DAY FROM date_val) as day,
        EXTRACT(DAYOFWEEK FROM date_val) as day_of_week,
        EXTRACT(DAYOFYEAR FROM date_val) as day_of_year,
        EXTRACT(WEEK FROM date_val) as week_of_year,
        
        -- Formatted Attributes
        FORMAT_DATE('%B', date_val) as month_name,
        FORMAT_DATE('%b', date_val) as month_name_short,
        FORMAT_DATE('%A', date_val) as day_name,
        FORMAT_DATE('%a', date_val) as day_name_short,
        
        -- Business Calendar
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) IN (1, 2, 3) THEN 'Q1'
            WHEN EXTRACT(MONTH FROM date_val) IN (4, 5, 6) THEN 'Q2'
            WHEN EXTRACT(MONTH FROM date_val) IN (7, 8, 9) THEN 'Q3'
            WHEN EXTRACT(MONTH FROM date_val) IN (10, 11, 12) THEN 'Q4'
        END as quarter_name,
        
        -- Week Classifications
        CASE EXTRACT(DAYOFWEEK FROM date_val)
            WHEN 1 THEN 'Sunday'
            WHEN 2 THEN 'Monday'
            WHEN 3 THEN 'Tuesday'
            WHEN 4 THEN 'Wednesday'
            WHEN 5 THEN 'Thursday'
            WHEN 6 THEN 'Friday'
            WHEN 7 THEN 'Saturday'
        END as weekday_name,
        
        CASE 
            WHEN EXTRACT(DAYOFWEEK FROM date_val) IN (1, 7) THEN 'Weekend'
            ELSE 'Weekday'
        END as weekday_indicator,
        
        -- Brazilian Holidays (major ones)
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) = 1 AND EXTRACT(DAY FROM date_val) = 1 THEN 'New Year'
            WHEN EXTRACT(MONTH FROM date_val) = 9 AND EXTRACT(DAY FROM date_val) = 7 THEN 'Independence Day'
            WHEN EXTRACT(MONTH FROM date_val) = 10 AND EXTRACT(DAY FROM date_val) = 12 THEN 'Our Lady of Aparecida'
            WHEN EXTRACT(MONTH FROM date_val) = 11 AND EXTRACT(DAY FROM date_val) = 2 THEN 'All Souls Day'
            WHEN EXTRACT(MONTH FROM date_val) = 11 AND EXTRACT(DAY FROM date_val) = 15 THEN 'Proclamation of Republic'
            WHEN EXTRACT(MONTH FROM date_val) = 12 AND EXTRACT(DAY FROM date_val) = 25 THEN 'Christmas'
            ELSE NULL
        END as brazilian_holiday,
        
        -- E-commerce Analytics
        CASE 
            WHEN EXTRACT(MONTH FROM date_val) = 11 THEN 'Black Friday Season'
            WHEN EXTRACT(MONTH FROM date_val) = 12 THEN 'Christmas Season'
            WHEN EXTRACT(MONTH FROM date_val) IN (1, 2) THEN 'New Year Season'
            WHEN EXTRACT(MONTH FROM date_val) IN (6, 7) THEN 'Winter Sale Season'
            ELSE 'Regular Season'
        END as shopping_season,
        
        -- Audit Fields
        CURRENT_TIMESTAMP() as created_at,
        'generated_date_dimension' as source_model
        
    FROM date_spine
)

SELECT * FROM date_dimension
