import csv
from pathlib import Path

RAW_FILE = Path("Data/raw/txs_features.csv")
MISSING_ID_FILE = Path("Scripts/missing_tx_ids.csv")

AUGMENTED_COLUMNS = [
    "in_txs_degree",
    "out_txs_degree",
    "total_BTC",
    "fees",
    "size",
    "num_input_addresses",
    "num_output_addresses",
    "in_BTC_min",
    "in_BTC_max",
    "in_BTC_mean",
    "in_BTC_median",
    "in_BTC_total",
    "out_BTC_min",
    "out_BTC_max",
    "out_BTC_mean",
    "out_BTC_median",
    "out_BTC_total",
]

MISSING_VALUES = {"", "na", "nan", "null", "none"}

with MISSING_ID_FILE.open(
    "r", encoding="utf-8-sig", newline=""
) as file:
    reader = csv.DictReader(file)
    missing_ids = {
        row["tx_id"].strip()
        for row in reader
    }

found_ids = set()
all_17_blank = 0
partial_blank = 0
no_blank = 0

with RAW_FILE.open(
    "r", encoding="utf-8-sig", newline=""
) as file:
    reader = csv.DictReader(file)

    id_candidates = ["tx_id", "txId"]
    id_column = next(
        (column for column in id_candidates
         if column in reader.fieldnames),
        None,
    )

    if id_column is None:
        raise ValueError(
            f"Transaction ID column not found. "
            f"CSV columns: {reader.fieldnames}"
        )

    missing_columns = [
        column
        for column in AUGMENTED_COLUMNS
        if column not in reader.fieldnames
    ]

    if missing_columns:
        raise ValueError(
            f"These augmented columns were not found: "
            f"{missing_columns}"
        )

    for row in reader:
        tx_id = row[id_column].strip()

        if tx_id not in missing_ids:
            continue

        found_ids.add(tx_id)

        values = [
            row[column].strip().lower()
            for column in AUGMENTED_COLUMNS
        ]

        missing_count = sum(
            value in MISSING_VALUES
            for value in values
        )

        if missing_count == 17:
            all_17_blank += 1
        elif missing_count > 0:
            partial_blank += 1
        else:
            no_blank += 1

not_found = len(missing_ids - found_ids)

print(
    f"Raw CSV comparison: "
    f"db_missing_ids={len(missing_ids)}, "
    f"found_in_raw_csv={len(found_ids)}, "
    f"all_17_blank_in_raw={all_17_blank}, "
    f"partial_blank_in_raw={partial_blank}, "
    f"no_blank_in_raw={no_blank}, "
    f"not_found_in_raw={not_found}"
)