# Olist Brazil E-commerce Data Quality & Cleaning Plan

## Overview
**Objective**: Implement data quality checks and cleaning for Olist Brazil e-commerce dataset

**Tech Stack**: dbt + BigQuery  
**Timeline**: 15-20 days

## Dataset
- **9 CSV files**: customers, geolocation, orders, order_items, payments, reviews, products, sellers, category_translations
- **Known Issues**: Zip code formatting, Portuguese accents, missing values, date inconsistencies

---

## Implementation Plan

### Phase 1: Project Setup & Infrastructure
**Duration**: 2-3 days

- [x] Verify conda 'elt' environment with dbt-bigquery
- [x] Initialize dbt project and configure BigQuery connection
- [x] Upload CSV files to BigQuery staging tables
- [x] Create dbt source definitions and basic staging models
- [x] Rename dbt folder to dbt_olist_data_quality

### Phase 2: Data Profiling & Quality Assessment
**Duration**: 3-4 days

- [ ] Create staging models for each source table
- [ ] Implement data profiling models to analyze:
  - Row counts and uniqueness
  - Null value percentages
  - Pattern analysis for text fields
- [ ] Map all foreign key relationships between tables
- [ ] Create tests to validate referential integrity
- [ ] Define data quality dimensions (completeness, validity, accuracy, consistency)

### Phase 3: Data Cleaning Implementation
**Duration**: 5-7 days

#### 3.1 Geolocation Data Cleaning
- [ ] **Zip Code Standardization**:
  - Pad 4-digit zip codes with leading zeros
  - Create lookup table for zip-to-city/state mapping

- [ ] **Geographic Coordinate Validation**:
  - Validate lat/lng ranges for Brazil
  - Cross-validate coordinates with city/state

- [ ] **Text Normalization**:
  - Remove Portuguese accents from city/state names
  - Trim whitespace and special characters

#### 3.2 Customer Data Cleaning
- [ ] **Customer Deduplication**:
  - Identify potential duplicate customers
  - Validate customer zip codes against geolocation data

#### 3.3 Order Data Cleaning
- [ ] **Date Validation**:
  - Ensure logical order of timestamps (order → approval → shipped → delivered)
  - Standardize timezone handling

- [ ] **Order Status Consistency**:
  - Validate order status transitions
  - Flag orders with inconsistent status/date combinations

#### 3.4 Payment Data Cleaning
- [ ] **Amount Validation**:
  - Flag negative or zero payment amounts
  - Validate payment amounts against order totals

- [ ] **Payment Method Standardization**:
  - Standardize payment type values
  - Validate installment logic

#### 3.5 Product & Seller Data Cleaning
- [ ] **Product Category Standardization**:
  - Apply category name translations
  - Standardize product dimensions and weights

- [ ] **Seller Validation**:
  - Validate seller geographic information
  - Check for duplicate seller entries

#### 3.6 Review Data Cleaning
- [ ] **Review Score Validation**:
  - Ensure review scores are within valid range (1-5)
  - Analyze review sentiment patterns

### Phase 4: Business Logic & Outlier Detection
**Duration**: 4-5 days

#### 4.1 Business Rule Implementation
- [ ] **Order Flow Validation**:
  - Define maximum reasonable delivery times by region
  - Validate order cancellation logic

- [ ] **Revenue Anomaly Detection**:
  - Identify unusually high-value orders
  - Analyze payment patterns by customer/seller

#### 4.2 Geographic Business Logic
- [ ] **Delivery Route Validation**:
  - Calculate distances between seller and customer locations
  - Identify potential geographic data errors

#### 4.3 Customer Behavior Analysis
- [ ] **Purchase Pattern Anomalies**:
  - Identify customers with unusual purchase frequencies
  - Analyze review patterns vs. purchase behavior

### Phase 5: Testing & Validation Framework
**Duration**: 3-4 days

#### 5.1 dbt Testing Implementation
- [ ] **Generic Tests**:
  - not_null tests for critical fields
  - relationships tests for foreign keys

- [ ] **Custom Data Quality Tests**:
  - Geographic coordinate range validation
  - Data freshness checks

#### 5.2 Data Quality Monitoring
- [ ] Create data quality scorecards
- [ ] Implement alerting for critical data quality issues
- [ ] Build data lineage documentation
- [ ] Create data quality trend analysis

### Phase 6: Documentation & Deployment
**Duration**: 2-3 days

#### 6.1 Documentation
- [ ] **Technical Documentation**:
  - dbt model documentation
  - Troubleshooting guides

- [ ] **Business Documentation**:
  - Data quality summary report
  - Known limitations and assumptions

#### 6.2 Deployment Preparation
- [ ] Performance optimization of SQL queries
- [ ] Production deployment checklist
- [ ] Rollback procedures documentation
- [ ] Handover documentation for downstream teams

## Business Rules & Validation Criteria

### Critical Business Rules
1. **Temporal Logic**: Order approval date >= Order purchase date; Review creation date >= Delivered date
2. **Geographic Constraints**: Brazilian zip codes (5-digit format); Longitude range: -73.9 to -28.8
3. **Financial Validation**: Payment amounts > 0; Freight costs reasonable for distance
4. **Review Logic**: Review scores 1-5 range; Review dates after delivery

### Outlier Detection Criteria
1. **Order Value**: Orders > 3 standard deviations from mean; Freight cost > 50% of product value
2. **Delivery Time**: Delivery times > 90 days; Same-day delivery for long distances
3. **Customer Behavior**: Customers with > 50 orders; Only 5-star or 1-star reviews

---

## Success Metrics
- **Completeness**: < 5% missing values in critical fields
- **Validity**: > 95% of records pass format validation
- **Accuracy**: > 98% referential integrity compliance
- **Performance**: SQL execution < 5 minutes per model; Full dbt run < 30 minutes
