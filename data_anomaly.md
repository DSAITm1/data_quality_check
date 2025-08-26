# Data Anomaly Identification Document

## Project Context

This document focuses on the **identification of data anomalies** within the geolocation dataset containing `geolocation_zip_code_prefix`, `geolocation_lat`, `geolocation_lng`, `geolocation_city`, `geolocation_state`, and geographic coordinates (`lat/lng`). Detecting anomalies early is critical for ensuring data integrity and reliability.

---

## Objective

- To define methods and processes for identifying anomalies in the dataset.
- To provide initial validation steps for anomaly detection results.
- To enable informed decisions for subsequent cleaning and remediation.

---

## Anomaly Identification Approach

### 1. Data Profiling

- Analyze column-level statistics: null counts, unique value counts, min/max values.
- Understand distributions for key fields (zip codes, city/state frequency).
- Identify unexpected data patterns or spikes.

### 2. Anomaly Detection Techniques

| Method          | Description                                        | Use Cases                               |
|-----------------|--------------------------------------------------|----------------------------------------|
| Statistical     | Outlier detection using Z-score, IQR, etc.       | Identify extreme outliers in lat/lng   |
| Rule-based      | Logical validation rules (e.g., zip format check)| Detect format or domain violations     |
| Cross-Field     | Check consistency (zip to city/state matching)   | Detect mismatched location mappings    |
| Duplicate Check | Identify exact or near-duplicate entries          | Remove inflated data volume             |

### 3. Common Anomaly Types to Monitor

| Anomaly Type             | Examples                                 | Impact                                  |
|--------------------------|------------------------------------------|-----------------------------------------|
| Null or Missing Values    | Empty zip codes or city names             | Causes analysis gaps or misattribution |
| Format Errors            | Zip codes with invalid length or chars    | Data parsing and matching errors        |
| Geographic Mismatches    | Lat/lng not matching city/state zip code  | Incorrect spatial analysis              |
| Multiple Locations per Zip| Same zip linked to different cities/states| Ambiguity in reporting or mapping       |
| Spelling Variations      | Different spellings or accents for cities | Duplicate records or misclassification  |

### 4. Validation Steps

- Sample flagged anomalies for manual inspection.
- Cross-validate with reference datasets or third-party APIs.
- Verify geographic anomalies using mapping and visualization tools.

---

## Identified Anomalies

### 1. Zip Code Length Issues
- The standard zip code digit length is **5 digits**.
- Some zip codes contain only **4 digits** because they were stored as integers, causing leading zeros to be dropped.
- This causes format inconsistencies and potential data interpretation errors.

### 2. One Zip Code with Multiple Cities or States
- Some zip code prefixes are linked to **multiple distinct cities or states**.
- This causes ambiguity in mapping and geolocation accuracy.
- It may indicate data entry errors, outdated or overlapping geographic boundaries.

### 3. Presence of Portuguese Accents in City and State Names
- City and state names contain **Portuguese accented characters** (e.g., á, ã, ç).
- Accents can cause mismatches in joins, lookups, or aggregations if normalization is not applied.
- Requires normalization or standardization for consistency.

---

## Next Steps for Each Anomaly

| Anomaly                  | Recommended Action                                |
|--------------------------|-------------------------------------------------|
| Zip Code Length Issues    | Convert zip codes to string and pad with zeros if needed to maintain 5-digit format. |
| Multiple Cities/States   | Investigate and resolve conflicting entries; possibly standardize or choose primary city/state. |
| Portuguese Accents       | Normalize text fields by removing accents or using consistent encoding across datasets. |

---

## References

- Statistical anomaly detection methods  
- Geospatial validation best practices  
- Data profiling tools and techniques  

---

*Document last updated: August 26, 2025*
