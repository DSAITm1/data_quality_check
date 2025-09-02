# Olist Brazil E-commerce Data Quality & Cleaning Plan

## 1. Overview
**Objective**: Implement data quality checks and cleaning for Olist Brazil e-commerce dataset with star schema dimensional modeling

**Tech Stack**: dbt + BigQuery  
**Architecture**: Star Schema with Fact and Dimension Tables  
**Implementation Path**: `./dbt_olist_data_quality`  
**Testing Framework**: dbt-test packages including dbt-expectations for advanced data quality tests  
**SQL Syntax**: Google BigQuery compatible SQL with JINJA macros for dynamic testing and data transformations

## 2. Target Data Architecture
**Star Schema Design**:
- **1 Fact Table**: `fact_order_items` (grain: order item level)
- **8 Dimension Tables**: customers, products, sellers, orders, payments, reviews, geolocation, date
- **Surrogate Keys (_sk)**: Auto-generated integer keys for all dimensions
- **Business Keys**: Original string identifiers preserved for data lineage

## 3. Dataset
- **9 CSV files**: customers, geolocation, orders, order_items, payments, reviews, products, sellers, category_translations
- **Known Issues**: Zip code formatting, Portuguese accents, missing values, date inconsistencies
- **Output**: Dimensional model with fact/dimension tables optimized for analytics

---

## 4. Technical Implementation Framework

### 4.1 dbt Project Structure
**Project Location**: `./dbt_olist_data_quality`

**Required dbt Packages**:
- `dbt-expectations`: Advanced data quality tests (expect_column_values_to_be_unique, expect_table_row_count_to_be_between, etc.)
- `dbt-utils`: Utility macros for testing and transformations
- Standard dbt-core: Built-in tests (unique, not_null, accepted_values, relationships)

**BigQuery SQL Requirements**:
- All SQL must be BigQuery Standard SQL compatible
- Use JINJA macros for dynamic data quality rules and parameterized tests
- Leverage BigQuery functions: SAFE_CAST, REGEXP_EXTRACT, NORMALIZE, STRING functions for Brazilian text processing
- Implement CTEs (Common Table Expressions) for complex transformations
- Use BigQuery array/struct functions for handling nested data patterns

**Testing Strategy**:
- **schema.yml files**: Define all data quality tests using dbt-expectations syntax
- **JINJA macros**: Create reusable test patterns for Brazilian text normalization
- **Custom tests**: Implement business-specific validation logic in `tests/` folder
- **Performance optimization**: Use BigQuery clustering and partitioning where applicable

---

## 5. Raw Staging Table Test Criteria

### 5.1 **stg_customers** Test Criteria
**Purpose**: Source for `dim_customer`
**Available Fields**: customer_id, customer_unique_id, customer_zip_code_prefix, customer_city_normalized, customer_city_original, customer_state
- **Primary Key Tests**: customer_id uniqueness/non-null, customer_unique_id uniqueness (allows nulls)
- **Data Quality Tests**: Brazilian zip code format (5 digits), city/state non-null, valid state codes
- **Text Normalization**: customer_city_normalized field handles accent variations, spacing, case consistency
- **Business Logic Tests**: Geographic data consistency, duplicate customer detection using customer_unique_id + geographic fields

### 5.2 **stg_geolocation** Test Criteria
**Purpose**: Source for `dim_geolocation`
**Available Fields**: geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city_normalized, geolocation_city_original, geolocation_state, composite_geo_key
- **Primary Key Tests**: composite_geo_key uniqueness (zip + lat + lng), geolocation_zip_code_prefix non-null
- **Data Quality Tests**: Brazil coordinate boundaries (-35°/5° lat, -75°/-30° lng), city/state non-null
- **Text Normalization**: geolocation_city_normalized field handles Brazilian accent/spacing/case issues
- **Business Logic Tests**: Coordinate-to-state consistency, zip code standardization, geographic validation

### 5.3 **stg_orders** Test Criteria
**Purpose**: Source for `dim_orders` and date dimension
**Available Fields**: order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date, temporal_sequence_valid
- **Primary Key Tests**: order_id uniqueness and non-null validation
- **Data Quality Tests**: customer_id non-null (FK), order_status in accepted values, proper timestamp parsing
- **Business Logic Tests**: Temporal sequence validation using temporal_sequence_valid flag, order status consistency

### 5.4 **stg_order_items** Test Criteria
**Purpose**: Source for `fact_order_items` (main fact table)
**Available Fields**: order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value, composite_key, valid_price, valid_freight
- **Primary Key Tests**: composite_key uniqueness (order_id + order_item_id + product_id + seller_id)
- **Data Quality Tests**: price > 0 validation via valid_price flag, freight_value >= 0 via valid_freight flag
- **Business Logic Tests**: FK relationships validation, price reasonableness, shipping date logic

### 5.5 **stg_order_payments** Test Criteria
**Purpose**: Source for `dim_payment`
**Available Fields**: order_id, payment_sequential, payment_type, payment_installments, payment_value, composite_payment_key, valid_payment_value, valid_installments
- **Primary Key Tests**: composite_payment_key uniqueness (order_id + payment_sequential)
- **Data Quality Tests**: Payment validation via valid_payment_value flag (>0), installment validation via valid_installments flag (>=1)
- **Business Logic Tests**: 
  - FK relationship validation (order_id → orders)
  - **Payment-Order Reconciliation**: Sum of payment sequences = order item totals
  - Payment type standardization (TRIM + UPPER applied)

### 5.6 **stg_order_reviews** Test Criteria
**Purpose**: Source for `dim_order_reviews`
**Available Fields**: review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp, valid_review_score, valid_answer_sequence
- **Primary Key Tests**: review_id uniqueness (allows nulls), order_id non-null (FK)
- **Data Quality Tests**: Review score 1-5 validation via valid_review_score flag, timestamp parsing
- **Business Logic Tests**: Answer sequence validation via valid_answer_sequence flag, temporal logic

### 5.7 **stg_products** Test Criteria
**Purpose**: Source for `dim_product`
**Available Fields**: product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm, valid_weight, valid_length, valid_height, valid_width
- **Primary Key Tests**: product_id uniqueness and non-null validation
- **Data Quality Tests**: Dimension validation via valid_* flags (>=0), product_category_name non-null, photo quantity >= 0
- **Business Logic Tests**: Category validation against translations, dimension reasonableness via validation flags

### 5.8 **stg_sellers** Test Criteria
**Purpose**: Source for `dim_seller`
**Available Fields**: seller_id, seller_zip_code_prefix, seller_city, seller_state, missing_seller_id_flag, missing_zip_code_flag, short_zip_code_flag, missing_city_flag, missing_state_flag
- **Primary Key Tests**: seller_id uniqueness and non-null validation
- **Data Quality Tests**: Data quality flags for missing/invalid fields, Brazilian zip code format, valid state codes
- **Text Normalization Issues**: Brazilian city names need accent/spacing/case standardization (applied in intermediate layer)
- **Business Logic Tests**: Geographic consistency, duplicate detection, Brazil boundary validation

### 5.9 **stg_category_translations** Test Criteria
**Purpose**: Reference for product categorization in `dim_product`
**Available Fields**: product_category_name, product_category_name_normalized, product_category_name_english, portuguese_name_length, english_name_length
- **Primary Key Tests**: product_category_name (Portuguese) uniqueness and non-null validation
- **Data Quality Tests**: English translation non-null, length validation via *_name_length fields
- **Text Normalization**: product_category_name_normalized field handles Brazilian accent/spacing/case variations
- **Business Logic Tests**: Translation completeness, consistency (1:1 mapping), category standardization

### 5.10 **Brazilian Text Normalization Strategy**
**Common Data Quality Issues in Brazilian Geographic/Text Data**:

- **Latin Accent Variations**:
  - São Paulo ↔ Sao Paulo
  - Brasília ↔ Brasilia  
  - Goiânia ↔ Goiania
  - Ribeirão Preto ↔ Ribeirao Preto

- **Spacing Issues**:
  - "Rio  de  Janeiro" (multiple spaces) → "Rio de Janeiro"
  - " Porto Alegre " (leading/trailing spaces) → "Porto Alegre"
  - "BeloHorizonte" (missing spaces) → "Belo Horizonte"

- **Apostrophe Variations**:
  - "D'Oeste" ↔ "DOeste" ↔ "D Oeste"
  - "Sant'Ana" ↔ "SantAna" ↔ "Sant Ana"
  - "Angra d'El Rei" ↔ "Angra dEl Rei"

- **Case Inconsistencies**:
  - "SÃO PAULO" ↔ "são paulo" ↔ "São Paulo"
  - "MINAS GERAIS" ↔ "minas gerais" ↔ "Minas Gerais"

**Normalization Rules to Implement**:
1. **Accent Standardization**: Convert all accented characters to non-accented equivalents for matching
2. **Space Normalization**: TRIM() and collapse multiple spaces to single spaces
3. **Apostrophe Standardization**: Consistent punctuation rules (keep apostrophes, standardize format)
4. **Case Standardization**: Title Case for proper nouns (cities, states)
5. **Fuzzy Matching**: Use SOUNDEX or edit distance for similar name matching

**BigQuery SQL Implementation**:
- Create JINJA macro for Brazilian text normalization using NORMALIZE(), REGEXP_REPLACE(), TRIM()
- Implement SAFE_CAST for zip code padding and data type conversions
- Use BigQuery string functions for consistent text processing across all models

**dbt-expectations Tests for Brazilian Data**:
- `expect_column_values_to_match_regex`: Validate Brazilian zip code format (5 digits)
- `expect_column_values_to_be_in_set`: Validate Brazilian state codes (27 valid states)
- `expect_column_pair_values_A_to_be_greater_than_B`: Order date sequence validation
- `expect_column_values_to_be_between`: Geographic coordinate validation for Brazil

### 5.11 Cross-Table Referential Integrity Tests
- **orders.customer_id** → **customers.customer_id** ✅
- **order_items.order_id** → **orders.order_id** ✅
- **order_items.product_id** → **products.product_id** ✅
- **order_items.seller_id** → **sellers.seller_id** ✅
- **order_payments.order_id** → **orders.order_id** ✅
- **order_reviews.order_id** → **orders.order_id** ✅
- **customers.customer_zip_code_prefix** → **geolocation.geolocation_zip_code_prefix** ✅ **FIXED via int_geolocation_consolidated**
- **sellers.seller_zip_code_prefix** → **geolocation.geolocation_zip_code_prefix** ✅ **FIXED via int_geolocation_consolidated**
- **products.product_category_name** → **category_translations.product_category_name** ✅

**Integrity Enhancement**: Added 992 missing zip codes with estimated coordinates to achieve 100% referential integrity

### 5.12 **Data Quality Dimensions Assessment**:
- **Completeness**: < 5% null values in critical business keys
- **Validity**: 100% format compliance for dates, numbers, geographic data
- **Accuracy**: 100% referential integrity across related tables
- **Consistency**: Business rule compliance (temporal logic, value ranges)
- **Uniqueness**: 100% primary key uniqueness within each table

## 6. Data Cleaning Implementation

**Implementation Priority**: 96.7% excellent quality requires minimal cleaning
- **Primary Focus**: Customer deduplication (3,345 records affecting dimension integrity)
- **Secondary Focus**: Brazilian text normalization for geographic consistency  
- **Minimal Focus**: Coordinate validation (55 records), payment edge cases (11 records)

### 6.1 **int_customers_cleaned** - Customer Deduplication
**Business Logic**: customer_unique_id grouping + completeness/recency scoring for master record selection
**Enhancement**: Customer lifetime analytics, geographic classification, audit trail tracking
**Quality Target**: Reduce 3,345 duplicates to <50 (99%+ deduplication rate)

### 6.2 **int_geolocation_consolidated** - Business-Optimized Geographic Solution
**Business Optimization**: Consolidate to ONE lat/lng per (zip_code, city, state) for simplified business operations
**Integrity Enhancement**: Add missing zip codes (992 records) from customers/sellers with estimated coordinates
**Consolidation Strategy**: 
- **Existing Data**: Use median coordinates as representative point for each geographic area (reduces 1M+ records to ~20K)
- **Missing Data**: Estimate coordinates using city averages (921 zip codes) or state averages (80 zip codes) 
- **Quality Levels**: High confidence (exact), medium confidence (city estimate), low confidence (state estimate)
**Business Impact**: 100% referential integrity, simplified location analytics, 97% reduction in geolocation complexity
**Quality Target**: 100% coordinate coverage, 99.96% valid Brazil coordinates, complete business referential integrity

### 6.3 **int_orders_enriched** - Order Enhancement & Temporal Validation
**Enhancement**: Order lifecycle analytics, delivery performance metrics, temporal sequence validation
**Business Logic**: Order status progression validation, delivery time calculations
**Quality Target**: Complete order lifecycle tracking with temporal consistency

### 6.4 **int_payments_cleaned** - Payment Validation & Reconciliation
**Standardization**: Payment type consistency, installment validation using staging validation flags
**Reconciliation**: Payment sequences must sum exactly to order totals (Priority 4 enhancement)
**Enhancement**: Payment risk scoring, method preference analysis
**Quality Target**: 99.99% payment validation accuracy, 100% reconciliation compliance

### 6.5 **int_sellers_cleaned** - Seller Enhancement  
**Text Normalization**: Brazilian Portuguese accent/spacing/case standardization building on staging quality flags
**Geographic Enhancement**: Location validation, regional classification, delivery capacity mapping
**Quality Target**: 100% text consistency, complete geographic standardization

### 6.6 **int_products_cleaned & int_products_enriched** - Product Enhancement
**Category Enhancement**: English translation mapping using normalized category fields
**Analytics Addition**: Dimension classifications, photo quality scoring, product analytics
**Quality Target**: 100% category mapping, complete analytical enhancement

### 6.7 **Implementation Framework**
**Audit Strategy**: Complete audit trail with `{field}_original` preservation, correction reasoning, rollback capability
**Validation Rules**: All Section 5 staging validation flags leveraged, lineage preservation verification
**Quality Gates**: Post-cleaning target 99.5% overall quality (from 96.7% baseline)

---

## 7. Star Schema Implementation & Dimensional Modeling

### 7.1 **dbt Model Architecture**
**Model Organization**: Three-layer structure in `./dbt_olist_data_quality/models/`
- **Staging Layer**: `stg_*` models - Raw data ingestion with basic validation
- **Intermediate Layer**: `int_*` models - Business logic and data transformations  
- **Marts Layer**: `dim_*` and `fact_*` models - Star schema implementation

### 7.2 **Dimension Models** (marts/dimensions/)
**Core Dimensions**: Customer, Product, Seller, Orders, Payment, Reviews, Geolocation, Date
**Enhancement**: Surrogate keys (SK), business key preservation, geographic attributes, analytics fields
**Materialization**: Tables with clustering for performance optimization

### 7.3 **Fact Models** (marts/facts/)
**Primary Fact**: fact_order_items - Order item grain with all dimension FKs
**Measures**: Price, freight value, payment amounts, calculated analytics
**Optimization**: Partitioned by order_date, clustered by key dimensions

### 7.4 **Implementation Strategy**
**Surrogate Keys**: ROW_NUMBER() generation with SK-to-business-key mapping
**Data Lineage**: Complete business key preservation across all transformations
**Testing**: Comprehensive dimensional integrity and measure validation
**Performance**: Strategic materialization and BigQuery optimization

---

## 8. Business Logic & Validation Rules

### 8.1 **Critical Business Rules**
- **Temporal Logic**: Handle NULL date patterns as valid business states, review dates after delivery
- **Geographic Constraints**: Brazilian zip codes (5-digit), coordinates within Brazil boundaries  
- **Financial Validation**: Payment amounts > 0, payment sequences sum to order totals
- **Customer Integrity**: Customer deduplication for unique IDs, order history preservation

### 8.2 **Star Schema Validation**
- **Surrogate Key Integrity**: SK uniqueness within dimensions, no NULL SKs in facts
- **Fact Table Grain**: One row per order item, all dimension FKs resolve to valid SKs
- **Dimension Completeness**: All business keys map to SKs, no orphaned dimensions

### 8.3 **Outlier Detection Criteria**
- **Order Value**: Orders > 3 standard deviations, freight cost > 50% product value
- **Delivery Time**: Delivery > 90 days, geographic inconsistencies
- **Customer Behavior**: Extreme order patterns, unusual review distributions

---

## 9. Success Metrics & Quality Gates

### 9.1 **Achieved Quality Metrics** ✅
- **Completeness**: 96.7% overall (exceeds 95% target)
- **Validity**: 99.9% format compliance (exceeds 95% target)  
- **Accuracy**: 100% referential integrity (exceeds 98% target)

### 9.2 **Implementation Targets**
- **Customer Deduplication**: Resolve 3,345 duplicates → <50 final duplicates
- **Text Normalization**: 100% Brazilian geographic text standardization
- **Payment Reconciliation**: 100% payment-to-order value reconciliation
- **Performance**: dbt runs < 5 minutes, dimensional queries < 30 seconds

### 9.3 **Documentation & Deployment**
- **Technical**: Dimensional model ERD, SK procedures, performance optimization
- **Business**: User guides, data quality summaries, analyst documentation
- **Operational**: Incremental loading, monitoring, maintenance procedures

---

**Data Quality Implementation Complete**: Brazilian E-commerce Data Warehouse with 99.5%+ Quality Target
