# Olist Data Quality & Cleaning Project

> Data quality checks and cleaning pipeline for Olist Brazil e-commerce dataset using dbt + BigQuery

## 🎯 Overview

This project implements comprehensive data quality checks, anomaly detection, and data cleaning for the Olist Brazil e-commerce dataset. The solution uses dbt (Data Build Tool) to create SQL transformations that run in Google BigQuery, ensuring scalable and maintainable data processing.

**Key Objectives:**
- Standardize and clean 9 CSV files containing e-commerce transaction data
- Implement business logic validation and outlier detection
- Create automated data quality monitoring and testing framework
- Deliver production-ready cleaned datasets for downstream analytics

## 🏗️ Architecture

```
Raw CSV Files → BigQuery Staging → dbt Transformations → Clean Data Marts
```

**Tech Stack:**
- **dbt**: Data transformation and testing
- **BigQuery**: Data warehouse and processing engine
- **Python**: Initial exploratory data analysis
- **Git**: Version control and collaboration

## 📊 Dataset

The project processes 9 CSV files from the Olist Brazil e-commerce platform:

| File | Description | Key Issues |
|------|-------------|------------|
| `olist_customers_dataset` | Customer information | Duplicate customers, inconsistent locations |
| `olist_geolocation_dataset` | Geographic coordinates | Missing zip code zeros, Portuguese accents |
| `olist_orders_dataset` | Order headers | Date sequence validation needed |
| `olist_order_items_dataset` | Order line items | Price validation, referential integrity |
| `olist_order_payments_dataset` | Payment transactions | Amount validation, payment method standardization |
| `olist_order_reviews_dataset` | Customer reviews | Score validation, sentiment analysis |
| `olist_products_dataset` | Product catalog | Category standardization, dimension validation |
| `olist_sellers_dataset` | Seller information | Geographic validation, deduplication |
| `product_category_name_translation` | Category translations | Missing mappings, text normalization |

## 🚀 Quick Start

### Prerequisites
- Conda environment with dbt-bigquery adapter
- Google Cloud Platform account with BigQuery access
- Git for version control

### Setup
```bash
# Clone the repository
git clone <repository-url>
cd data_quality_check

# Activate conda environment
conda activate elt

# Navigate to dbt project
cd dbt_olist_data_quality

# Test database connection
dbt debug

# Install dependencies
dbt deps

# Run data quality checks
dbt test

# Execute transformations
dbt run

# Generate documentation
dbt docs generate
dbt docs serve
```

## 📁 Project Structure

```
data_quality_check/
├── README.md                    # This file
├── DATA_QUALITY_PLAN.md         # Detailed implementation plan
├── data_anomaly.md              # Data anomaly analysis
├── dbt_olist_data_quality/      # dbt project folder
│   ├── dbt_project.yml          # Main dbt configuration
│   ├── profiles.yml             # BigQuery connection (local only)
│   ├── packages.yml             # dbt packages for data quality
│   ├── BIGQUERY_SETUP.md        # Setup instructions
│   ├── models/
│   │   ├── staging/             # Raw data staging
│   │   │   ├── sources.yml      # Source table definitions
│   │   │   └── stg_customers.sql # Example staging model
│   │   ├── intermediate/        # Cleaning transformations
│   │   ├── data_quality/        # Quality monitoring
│   │   └── marts/              # Final clean datasets
│   ├── tests/                   # Custom tests
│   ├── macros/                 # Reusable SQL
│   └── dbt_packages/           # Installed packages
└── logs/                       # dbt logs
```

## 📋 Key Documents

- **[📋 Data Quality Plan](DATA_QUALITY_PLAN.md)**: Comprehensive implementation roadmap with phases, timelines, and deliverables
- **[🔍 Data Anomaly Analysis](data_anomaly.md)**: Detailed analysis of identified data quality issues and anomalies
- **[📊 EDA Plan](../EDA_PLAN.md)**: Exploratory data analysis methodology and findings

## 🎯 Data Quality Framework

### Quality Dimensions
- **Completeness**: Missing value analysis and handling
- **Validity**: Format and domain validation
- **Accuracy**: Cross-field and referential integrity validation
- **Consistency**: Standardization of categorical values and text
- **Uniqueness**: Duplicate detection and resolution

### Business Rules
- **Temporal Logic**: Order date sequences (purchase → approval → shipping → delivery)
- **Geographic Constraints**: Brazilian coordinate boundaries and zip code formatting
- **Financial Validation**: Payment amount consistency and fraud detection
- **Review Logic**: Rating ranges and review-order relationships

## 🧪 Testing Strategy

The project implements comprehensive testing using dbt's testing framework:

- **Generic Tests**: Standard dbt tests (not_null, unique, relationships)
- **Custom Tests**: Business rule validation and geographic constraints
- **Data Quality Monitoring**: Automated scorecards and alerting
- **Performance Tests**: Query execution time and resource usage monitoring

## 📈 Success Metrics

| Metric | Target | Description |
|--------|--------|-------------|
| Completeness | < 5% missing values | Critical fields should have minimal missing data |
| Validity | > 95% valid records | Records should pass format validation |
| Accuracy | > 98% integrity | Referential integrity should be maintained |
| Performance | < 5 min per model | SQL queries should execute efficiently |

## 🚧 Current Status

- [x] Project setup and planning
- [x] Data anomaly identification
- [ ] dbt project initialization
- [ ] BigQuery data ingestion
- [ ] Data cleaning implementation
- [ ] Business logic validation
- [ ] Testing framework
- [ ] Documentation and deployment

## 🤝 Contributing

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Development Guidelines
- Follow dbt best practices for model naming and organization
- Document all business rules and assumptions
- Include tests for all new models and transformations
- Update documentation with any changes

## 📞 Support

For questions or issues:
- Check the [Data Quality Plan](DATA_QUALITY_PLAN.md) for detailed implementation guidance
- Review the [Data Anomaly Analysis](data_anomaly.md) for known data issues
- Open an issue in this repository for bugs or feature requests

---

**Project Timeline**: 15-20 days  
**Last Updated**: August 29, 2025  
**Version**: 1.0
