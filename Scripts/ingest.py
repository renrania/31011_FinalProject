
import csv
import hashlib
import logging
from pathlib import Path

from google.cloud import storage

# ==========================================
# 1. Configuration
# ==========================================

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "data" / "raw"

BUCKET_NAME = "aml_raw"

CSV_FILES = [
    "txs_features.csv",
    "txs_classes.csv",
    "txs_edgelist.csv",
]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)

logger = logging.getLogger(__name__)


# ==========================================
# 2. Validate CSV files
# ==========================================

def validate_csv(file_path):
    """Validate CSV structure using streaming reads."""

    if not file_path.is_file():
        raise FileNotFoundError(f"File not found: {file_path}")

    if file_path.stat().st_size == 0:
        raise ValueError(f"Empty file: {file_path.name}")

    row_count = 0

    with open(file_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.reader(f, strict=True)

        header = next(reader, None)

        if not header or any(not col.strip() for col in header):
            raise ValueError(f"Invalid header: {file_path.name}")

        expected_columns = len(header)

        # Process rows one at a time to limit memory usage
        for row in reader:
            row_count += 1

            if len(row) != expected_columns:
                raise ValueError(
                    f"{file_path.name}, row {row_count + 1}: "
                    f"Expected {expected_columns} columns, "
                    f"found {len(row)}"
                )

    if row_count == 0:
        raise ValueError(f"No data rows: {file_path.name}")

    logger.info(
        "%s: %s rows, %s columns validated",
        file_path.name, row_count, expected_columns
    )

    return row_count


from collections import Counter

def profile_csv(file_path):
    """Profile CSV data without loading it all into memory."""

    missing_counts = Counter()
    row_count = 0

    with open(file_path, "r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)

        columns = reader.fieldnames

        if not columns:
            raise ValueError(f"No header found: {file_path.name}")

        for row in reader:
            row_count += 1

            for col, value in row.items():
                if value is None or value.strip() == "":
                    missing_counts[col] += 1

    logger.info("DATA PROFILE: %s", file_path.name)
    logger.info("Total rows: %s", row_count)
    logger.info("Total columns: %s", len(columns))

    for col, count in missing_counts.items():
        logger.info(
            "Missing values in %s: %s (%.2f%%)",
            col,
            count,
            count / row_count * 100
        )



# ==========================================
# 3. Calculate file checksum
# ==========================================

def calculate_sha256(file_path):
    """Calculate SHA256 without loading the whole file."""

    sha256 = hashlib.sha256()

    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            sha256.update(chunk)

    return sha256.hexdigest()


# ==========================================
# 4. Upload CSV to GCS
# ==========================================

def upload_csv(bucket, file_path):
    """Upload file, skipping unchanged objects."""

    object_name = f"raw/{file_path.name}"
    blob = bucket.blob(object_name)

    local_hash = calculate_sha256(file_path)

    if blob.exists():
        blob.reload()

        remote_hash = (blob.metadata or {}).get("sha256")

        if remote_hash == local_hash:
            logger.info("SKIPPED (unchanged): %s", object_name)
            return

    blob.metadata = {"sha256": local_hash}

    blob.upload_from_filename(
        str(file_path),
        content_type="text/csv",
        timeout=120,
)

    logger.info(
        "UPLOADED: gs://%s/%s",
        bucket.name, object_name
    )


# ==========================================
# 5. Main ingestion pipeline
# ==========================================

def main():
    logger.info("Starting AML data ingestion")

    client = storage.Client()
    bucket = client.get_bucket(BUCKET_NAME)

    # Validate all files before uploading any
    for filename in CSV_FILES:
        file_path = DATA_DIR / filename

        validate_csv(file_path)
        profile_csv(file_path)

    # Upload all validated files
    for filename in CSV_FILES:
        upload_csv(bucket, DATA_DIR / filename)

    logger.info("Ingestion completed successfully")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        logger.exception("Ingestion failed")
        raise
