/*
  Macro for generating surrogate keys using dbt_utils
  Provides consistent hash-based surrogate key generation across all dimensions
*/

{% macro generate_surrogate_key(columns) %}
  {{ dbt_utils.generate_surrogate_key(columns) }}
{% endmacro %}

/*
  Macro for creating unknown/missing value records
  Standardizes handling of missing dimension members
*/
{% macro unknown_dimension_record(key_column_name, description_columns={}) %}
  SELECT 
    '{{ key_column_name }}_unknown' as {{ key_column_name }},
    {% for column, default_value in description_columns.items() %}
    '{{ default_value }}' as {{ column }}{{ "," if not loop.last }}
    {% endfor %}
{% endmacro %}

/*
  Macro for audit columns
  Adds consistent audit fields to all dimensional tables
*/
{% macro add_audit_columns() %}
  CURRENT_TIMESTAMP() as dbt_created_at,
  CURRENT_TIMESTAMP() as dbt_updated_at,
  '{{ invocation_id }}' as dbt_batch_id
{% endmacro %}

/*
  Macro for dimension table template
  Provides consistent structure for all dimension tables
*/
{% macro dimension_table_select(
    source_table,
    natural_key_columns,
    descriptive_columns,
    surrogate_key_name
) %}
  SELECT 
    {{ generate_surrogate_key(natural_key_columns) }} as {{ surrogate_key_name }},
    {% for column in natural_key_columns %}
    {{ column }},
    {% endfor %}
    {% for column in descriptive_columns %}
    {{ column }}{{ "," if not loop.last }}
    {% endfor %},
    {{ add_audit_columns() }}
  FROM {{ source_table }}
{% endmacro %}
