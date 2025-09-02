{{ config(materialized='table') }}

-- Final Data Quality Summary Report
WITH overall_metrics AS (
  SELECT 
    'Overall Summary' as report_section,
    COUNT(DISTINCT table_name) as total_tables_processed,
    SUM(CASE WHEN data_type = 'Raw Data' THEN total_records ELSE 0 END) as raw_total_records,
    SUM(CASE WHEN data_type = 'Cleaned Data' THEN total_records ELSE 0 END) as cleaned_total_records,
    SUM(CASE WHEN data_type = 'Raw Data' THEN total_issues ELSE 0 END) as raw_total_issues,
    SUM(CASE WHEN data_type = 'Cleaned Data' THEN total_issues ELSE 0 END) as cleaned_total_issues,
    ROUND(AVG(CASE WHEN data_type = 'Raw Data' THEN data_quality_score_pct END), 2) as avg_raw_quality_score,
    ROUND(AVG(CASE WHEN data_type = 'Cleaned Data' THEN data_quality_score_pct END), 2) as avg_cleaned_quality_score
  FROM {{ ref('data_quality_validation') }}
),

table_improvements AS (
  SELECT 
    'Table Improvements' as report_section,
    table_name,
    MAX(CASE WHEN data_type = 'Raw Data' THEN data_quality_score_pct END) as raw_score,
    MAX(CASE WHEN data_type = 'Cleaned Data' THEN data_quality_score_pct END) as cleaned_score,
    MAX(CASE WHEN data_type = 'Cleaned Data' THEN data_quality_score_pct END) - 
    MAX(CASE WHEN data_type = 'Raw Data' THEN data_quality_score_pct END) as improvement_points,
    MAX(CASE WHEN data_type = 'Raw Data' THEN total_issues END) as raw_issues_count,
    MAX(CASE WHEN data_type = 'Cleaned Data' THEN total_issues END) as cleaned_issues_count
  FROM {{ ref('data_quality_validation') }}
  GROUP BY table_name
),

business_impact AS (
  SELECT 
    'Business Impact' as report_section,
    'Data Quality Standards Met' as metric_name,
    CASE 
      WHEN AVG(CASE WHEN data_type = 'Cleaned Data' THEN data_quality_score_pct END) >= 95 
      THEN 'YES - Exceeds 95% target'
      ELSE 'NO - Below 95% target'
    END as status,
    ROUND(AVG(CASE WHEN data_type = 'Cleaned Data' THEN data_quality_score_pct END), 2) as actual_score
  FROM {{ ref('data_quality_validation') }}
  
  UNION ALL
  
  SELECT 
    'Business Impact' as report_section,
    'Referential Integrity' as metric_name,
    CASE 
      WHEN AVG(referential_integrity_percentage) >= 95 
      THEN 'EXCELLENT - Average ' || ROUND(AVG(referential_integrity_percentage), 2) || '%'
      ELSE 'NEEDS IMPROVEMENT - Average ' || ROUND(AVG(referential_integrity_percentage), 2) || '%'
    END as status,
    ROUND(AVG(referential_integrity_percentage), 2) as actual_score
  FROM {{ ref('referential_integrity_analysis') }}
),

success_criteria AS (
  SELECT 
    'Success Criteria Assessment' as report_section,
    'Completeness: < 5% missing values' as criteria,
    CASE 
      WHEN (SELECT AVG(null_percentage_field1 + null_percentage_field2 + null_percentage_field3) / 3 
            FROM {{ ref('data_profile_summary') }}) < 5 
      THEN 'PASSED'
      ELSE 'FAILED'
    END as status,
    (SELECT ROUND(AVG(null_percentage_field1 + null_percentage_field2 + null_percentage_field3) / 3, 2) 
     FROM {{ ref('data_profile_summary') }}) as actual_value
  
  UNION ALL
  
  SELECT 
    'Success Criteria Assessment' as report_section,
    'Validity: > 95% format validation' as criteria,
    CASE 
      WHEN (SELECT AVG(data_quality_percentage1 + data_quality_percentage2) / 2 
            FROM {{ ref('data_profile_summary') }}) > 95 
      THEN 'PASSED'
      ELSE 'FAILED'
    END as status,
    (SELECT ROUND(AVG(data_quality_percentage1 + data_quality_percentage2) / 2, 2) 
     FROM {{ ref('data_profile_summary') }}) as actual_value
  
  UNION ALL
  
  SELECT 
    'Success Criteria Assessment' as report_section,
    'Accuracy: > 98% referential integrity' as criteria,
    CASE 
      WHEN (SELECT AVG(referential_integrity_percentage) FROM {{ ref('referential_integrity_analysis') }}) > 98 
      THEN 'PASSED'
      ELSE 'FAILED'
    END as status,
    (SELECT ROUND(AVG(referential_integrity_percentage), 2) FROM {{ ref('referential_integrity_analysis') }}) as actual_value
)

-- Combine all sections into final report
SELECT 
  report_section,
  'Total Tables Processed' as metric,
  CAST(total_tables_processed AS STRING) as value,
  '' as details
FROM overall_metrics

UNION ALL

SELECT 
  report_section,
  'Raw Data Quality Score' as metric,
  CAST(avg_raw_quality_score AS STRING) || '%' as value,
  CAST(raw_total_issues AS STRING) || ' total issues across ' || CAST(raw_total_records AS STRING) || ' records' as details
FROM overall_metrics

UNION ALL

SELECT 
  report_section,
  'Cleaned Data Quality Score' as metric,
  CAST(avg_cleaned_quality_score AS STRING) || '%' as value,
  CAST(cleaned_total_issues AS STRING) || ' total issues across ' || CAST(cleaned_total_records AS STRING) || ' records' as details
FROM overall_metrics

UNION ALL

SELECT 
  report_section,
  table_name || ' Improvement' as metric,
  CAST(improvement_points AS STRING) || ' points (' || CAST(raw_score AS STRING) || '% → ' || CAST(cleaned_score AS STRING) || '%)' as value,
  'Issues reduced from ' || CAST(raw_issues_count AS STRING) || ' to ' || CAST(cleaned_issues_count AS STRING) as details
FROM table_improvements

UNION ALL

SELECT 
  report_section,
  metric_name as metric,
  status as value,
  'Score: ' || CAST(actual_score AS STRING) || '%' as details
FROM business_impact

UNION ALL

SELECT 
  report_section,
  criteria as metric,
  status as value,
  'Actual: ' || CAST(actual_value AS STRING) as details
FROM success_criteria

ORDER BY 
  CASE report_section
    WHEN 'Overall Summary' THEN 1
    WHEN 'Table Improvements' THEN 2  
    WHEN 'Business Impact' THEN 3
    WHEN 'Success Criteria Assessment' THEN 4
  END,
  metric
