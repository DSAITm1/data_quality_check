/*
  Macro for Brazilian text normalization
  Handles common data quality issues in Brazilian geographic/text data:
  - Latin accent variations (São Paulo ↔ Sao Paulo)
  - Multiple spaces ("Rio  de  Janeiro" → "Rio de Janeiro") 
  - Leading/trailing spaces
  - Case inconsistencies
*/

{% macro normalize_brazilian_text(column_name) %}
  TRIM(
    REGEXP_REPLACE(
      UPPER(
        NORMALIZE({{ column_name }}, NFD)
      ), 
      r'[^\x00-\x7F]+', ''  -- Remove non-ASCII characters (accents)
    )
  )
{% endmacro %}

/*
  Macro for consistent space normalization
  Collapses multiple spaces to single spaces
*/
{% macro normalize_spaces(column_name) %}
  TRIM(
    REGEXP_REPLACE({{ column_name }}, r'\s+', ' ')
  )
{% endmacro %}

/*
  Macro for Brazilian zip code formatting
  Pads 4-digit zip codes with leading zeros to make them 5-digit
*/
{% macro normalize_brazilian_zipcode(zipcode_column) %}
  LPAD(CAST({{ zipcode_column }} AS STRING), 5, '0')
{% endmacro %}

/*
  Macro for Title Case formatting (for city/state names)
  Converts text to proper title case
*/
{% macro title_case(column_name) %}
  INITCAP(LOWER({{ column_name }}))
{% endmacro %}

/*
  Comprehensive Brazilian geographic text cleaning
  Combines normalization, space handling, and title case
*/
{% macro clean_brazilian_geographic_text(column_name) %}
  {{ title_case(normalize_spaces(normalize_brazilian_text(column_name))) }}
{% endmacro %}
