# Automated Data Ingestion Guide

## 1. Overview

The automated data ingestion pipeline (`Scripts/ingest.py`) is designed to validate, profile, and upload the raw Elliptic++ datasets to Google Cloud Storage (GCS).

The pipeline provides the following functionalities:

- CSV file existence and structure validation.
- Header and column count validation.
- Row count verification.
- Missing-value profiling.
- Automated data upload to Google Cloud Storage.
- SHA256 checksum comparison for file-level idempotency.
- Execution logging and error handling.

The pipeline preserves the original datasets without modifying, deleting, or imputing missing values.

## 2. Prerequisites

Before running the ingestion pipeline, ensure that the following requirements are satisfied:

- Python is installed.
- Required Python packages are installed.
- The three Elliptic++ CSV files are available locally.
- Google Cloud CLI is installed for local authentication.
- A valid Google Cloud account is available.
- Appropriate IAM permissions for the target GCS bucket have been granted.

## 3. Repository Setup and Dependency Installation

Clone the project repository:

```bash
git clone https://github.com/renrania/31011_FinalProject.git
cd 31011_FinalProject
```

Install the required Python dependencies:

```bash
python -m pip install -r requirements.txt
```

The ingestion pipeline requires the `google-cloud-storage` Python package, which is specified in `requirements.txt`.

## 4. Data Preparation

The project uses three CSV files from the Elliptic++ dataset.

**Original data source:** https://github.com/git-disl/EllipticPlusPlus

| File | Description | Expected Rows | Columns |
|---|---|---:|---:|
| `txs_features.csv` | Transaction IDs, time steps, and transaction features | 203,769 | 184 |
| `txs_classes.csv` | Transaction classification labels | 203,769 | 2 |
| `txs_edgelist.csv` | Directed transaction relationships | 234,355 | 2 |

Due to their large file sizes, the raw datasets are not included in the GitHub repository.

Create the local data directory from the project root if it does not already exist:

```bash
mkdir -p data/raw
```

Download the three CSV files from the original data source and place them in the following directory:

```text
31011_FinalProject/
├── data/
│   └── raw/
│       ├── txs_features.csv
│       ├── txs_classes.csv
│       └── txs_edgelist.csv
├── Scripts/
│   └── ingest.py
├── docs/
│   └── ingest.md
├── requirements.txt
├── .gitignore
└── README.md
```

Ensure that all filenames and directory names match the expected structure.

The `data/raw/` directory is excluded from version control through `.gitignore`.

## 5. Google Cloud Storage Configuration

The current ingestion pipeline uses the following shared GCS bucket:

```text
gs://aml_raw/
```

The uploaded datasets are stored under the `raw/` prefix:

```text
gs://aml_raw/raw/
├── txs_features.csv
├── txs_classes.csv
└── txs_edgelist.csv
```

### 5.1 IAM Permissions

Team members must be granted appropriate Google Cloud IAM permissions before accessing the shared bucket.

The ingestion script requires permissions to:

- Retrieve bucket metadata.
- Check whether objects already exist.
- Read existing object metadata.
- Upload new objects.
- Replace existing objects when the source files have changed.

The recommended bucket-level IAM role for object operations is **Storage Object User (`roles/storage.objectUser`)**.

Because the current script uses `client.get_bucket()`, users also require the `storage.buckets.get` permission to retrieve bucket metadata. The bucket administrator must ensure this permission is available through an appropriate IAM role.

### 5.2 Google Cloud Authentication

Install the Google Cloud CLI if it is not already installed:

https://cloud.google.com/sdk/docs/install

Configure Application Default Credentials (ADC) by running:

```bash
gcloud auth application-default login
```

Sign in using the Google account that has been granted access to the shared GCS bucket.

The Google Cloud Storage Python client automatically uses these credentials to authenticate API requests.

**Security Notice:** Do not upload Google Cloud credentials, service account keys, passwords, or other sensitive authentication files to GitHub.

## 6. Running the Ingestion Pipeline

After installing the dependencies, preparing the datasets, and configuring Google Cloud authentication, navigate to the project root directory and execute:

```bash
python Scripts/ingest.py
```

The ingestion pipeline performs the following operations:

1. Connects to the target GCS bucket.
2. Validates the structure of all three CSV files.
3. Profiles the datasets and reports missing values.
4. Calculates the SHA256 checksum of each local file.
5. Compares the local checksum with the metadata of the corresponding GCS object.
6. Uploads new or modified files and skips unchanged files.
7. Reports the execution status through logging.

## 7. Expected Output

### 7.1 Initial Execution

When the datasets do not already exist in the GCS bucket, a successful execution should include the following messages:

```text
INFO - Starting AML data ingestion
INFO - txs_features.csv: 203769 rows, 184 columns validated
INFO - txs_classes.csv: 203769 rows, 2 columns validated
INFO - txs_edgelist.csv: 234355 rows, 2 columns validated

INFO - UPLOADED: gs://aml_raw/raw/txs_features.csv
INFO - UPLOADED: gs://aml_raw/raw/txs_classes.csv
INFO - UPLOADED: gs://aml_raw/raw/txs_edgelist.csv

INFO - Ingestion completed successfully
```

Additional data profiling messages will also be displayed during execution.

### 7.2 Repeated Execution

When the datasets already exist in GCS and their contents remain unchanged, the pipeline should produce the following messages:

```text
INFO - SKIPPED (unchanged): raw/txs_features.csv
INFO - SKIPPED (unchanged): raw/txs_classes.csv
INFO - SKIPPED (unchanged): raw/txs_edgelist.csv

INFO - Ingestion completed successfully
```

This confirms that unchanged files are not uploaded repeatedly.

## 8. Data Quality Findings

During ingestion testing, the following data quality observations were identified:

| Dataset | Data Quality Findings |
|---|---|
| `txs_features.csv` | 17 augmented feature columns contain 965 missing values each, representing approximately 0.47% of the records per column. |
| `txs_classes.csv` | No empty fields detected. |
| `txs_edgelist.csv` | No empty fields detected. |

The missing-value profiling function currently identifies empty or whitespace-only fields. Textual missing-value indicators such as `NaN` and `NULL` are not automatically classified as missing values.

Missing values are reported but not modified during ingestion to preserve the integrity of the raw data layer.

Further data cleaning and transformation will be performed during downstream processing.

## 9. Idempotency and Reproducibility

The ingestion pipeline implements file-level idempotency through SHA256 checksum comparison.

For each CSV file:

- If the corresponding GCS object does not exist, the file is uploaded.
- If the local checksum matches the checksum stored in the GCS object metadata, the upload is skipped.
- If the checksums differ, the existing GCS object is replaced with the updated file.

Repeated execution with unchanged source files does not result in redundant uploads.

Database-level duplicate prevention is handled separately during relational database ingestion.

To reproduce the ingestion pipeline, users must have access to the original datasets, the required Python dependencies, and an appropriately configured GCS bucket.

The current script uses `aml_raw` as a hardcoded bucket name. Independent users who wish to reproduce the pipeline in their own Google Cloud environment must create a bucket and update the bucket name in `ingest.py` accordingly.

## 10. Troubleshooting

| Error | Possible Cause | Recommended Solution |
|---|---|---|
| `ModuleNotFoundError` | Required Python package is missing | Run `python -m pip install -r requirements.txt`. |
| `FileNotFoundError` | CSV files are missing or stored in the wrong directory | Verify the `data/raw/` directory and filenames. |
| `DefaultCredentialsError` | Google Cloud authentication is not configured | Run `gcloud auth application-default login`. |
| `403 Forbidden` | Insufficient GCS IAM permissions | Contact the bucket administrator to verify access permissions. |
| `404 Not Found` | Incorrect or nonexistent bucket name | Verify the bucket name in `ingest.py`. |
| CSV validation error | Invalid CSV structure or inconsistent column counts | Verify the integrity of the original dataset. |

## 11. Testing Status

The ingestion pipeline has successfully completed initial upload and repeated execution testing.

- [x] CSV structure validation
- [x] Row and column count checks
- [x] Missing-value profiling
- [x] Google Cloud Storage connectivity
- [x] Initial upload of all three datasets
- [x] SHA256 checksum comparison
- [x] File-level idempotency testing
- [x] Successful pipeline execution
- [ ] Independent reproduction by another team member

---

[Back to Project README](../README.md)
