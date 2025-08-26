# Geolocation Data Cleaning Project

## Overview

This repository contains code and documentation to clean and validate geolocation data, including zip code prefixes, city, state, and lat/lng coordinates. The goal is to standardize location data for accurate analysis and reporting.

## Data Description

- **geolocation_zip_code_prefix**: Partial postal code prefix used for grouping locations.
- **geolocation_city**: City name associated with zip code prefixes.
- **geolocation_state**: State name/abbreviation.
- **latitude** and **longitude**: Geographic coordinates of locations.

## Data Cleaning Tasks

1. Standardize zip code prefix formats.
2. Normalize city and state names (remove accents, trim spaces, unify casing).
3. Cross-validate zip codes against city and state.
4. Flag records with multiple cities or states per zip prefix.
5. Validate lat/lng coordinates lie within expected boundaries.
6. Deduplicate inconsistent or duplicate records.

## Key Files

- `cleaning_scripts/`: SQL or Python scripts used for cleaning.
- `data_quality_checks/`: Queries and reports identifying data issues.
- `data_flag.md`: Documentation on data quality flagging logic.

## How to Use

1. Clone this repo.
2. Run cleaning scripts against your data warehouse (e.g., BigQuery).
3. Review flagged records for manual inspection.
4. Generate clean datasets for downstream analytics.

## Contributing

Feel free to contribute improvements or raise issues.
