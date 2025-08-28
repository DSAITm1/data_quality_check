# BigQuery Configuration Instructions

To complete the BigQuery setup, you need to:

## 1. Update profiles.yml with your BigQuery details:

```yaml
olist_data_quality:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      keyfile: /path/to/your/service-account-key.json  # Update this path
      project: your-gcp-project-id                     # Update this
      dataset: olist_dev                               # Development dataset
      threads: 4
      timeout_seconds: 300
      location: US                                     # or your preferred location
      priority: interactive
      retries: 1
```

## 2. Authentication Options:

### Option A: Service Account Key (Recommended for development)
1. Go to Google Cloud Console
2. Navigate to IAM & Admin > Service Accounts
3. Create a new service account or use existing one
4. Download the JSON key file
5. Update the `keyfile` path in profiles.yml

### Option B: Application Default Credentials
```yaml
      method: oauth
      # Remove keyfile line
```

### Option C: Environment Variables
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
```

## 3. Required BigQuery Permissions:
- BigQuery Data Editor
- BigQuery Job User
- BigQuery User

## 4. Update Source Schema:
In `models/staging/sources.yml`, update the schema name to match your BigQuery dataset:
```yaml
schema: "your_actual_staging_dataset_name"
```

## 5. Test Connection:
```bash
dbt debug
```

This should show a successful connection to BigQuery.
