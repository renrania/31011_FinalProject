import csv
from getpass import getpass
from pathlib import Path

import mysql.connector


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = PROJECT_ROOT / "data" / "raw"

DATABASE = "elliptic_project"
HOST = "127.0.0.1"
PORT = 3306
USER = "root"
BATCH_SIZE = 500

# 先导入被其他表引用的交易特征表，再导入标签和边
IMPORT_FILES = [
    ("txs_features.csv", "txs_features"),
    ("txs_classes.csv", "txs_classes"),
    ("txs_edgelist.csv", "txs_edges"),
]


def normalize_header(header: str, table_name: str) -> str:
    """将 CSV 表头转换成数据库列名的匹配形式。"""
    name = "_".join(header.strip().lower().split())

    # 特征 CSV 的交易编号列叫 txId，数据库列叫 tx_id
    if table_name == "txs_features" and name == "txid":
        return "tx_id"

    return name


def get_database_columns(cursor, table_name: str) -> list[str]:
    cursor.execute(f"SHOW COLUMNS FROM `{table_name}`")
    return [row[0] for row in cursor.fetchall()]


def load_csv(cursor, connection, file_path: Path, table_name: str) -> int:
    with file_path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.reader(csv_file)
        headers = next(reader, None)

        if not headers:
            raise ValueError(f"{file_path.name} 是空文件或缺少表头。")

        actual_columns = get_database_columns(cursor, table_name)
        actual_by_normalized_name = {
            column.lower(): column for column in actual_columns
        }

        target_columns = []
        for header in headers:
            normalized = normalize_header(header, table_name)
            actual_name = actual_by_normalized_name.get(normalized)

            if actual_name is None:
                raise ValueError(
                    f"{file_path.name} 中的列 {header!r} "
                    f"无法匹配 MySQL 表 {table_name} 的列。"
                )

            target_columns.append(actual_name)

        if len(set(target_columns)) != len(target_columns):
            raise ValueError(f"{file_path.name} 中存在重复或冲突的列名。")

        missing_columns = set(actual_columns) - set(target_columns)
        if missing_columns:
            raise ValueError(
                f"{file_path.name} 缺少数据库表 {table_name} 的列："
                f"{sorted(missing_columns)}"
            )

        column_sql = ", ".join(f"`{column}`" for column in target_columns)
        placeholders = ", ".join(["%s"] * len(target_columns))
        insert_sql = (
            f"INSERT INTO `{table_name}` ({column_sql}) "
            f"VALUES ({placeholders})"
        )

        batch = []
        inserted_count = 0

        for line_number, row in enumerate(reader, start=2):
            if len(row) != len(headers):
                raise ValueError(
                    f"{file_path.name} 第 {line_number} 行有 "
                    f"{len(row)} 个值，但表头有 {len(headers)} 列。"
                )

            # 空白、NaN、NULL 转成 SQL NULL；其他值交给 MySQL 转换类型
            values = tuple(
                None
                if value.strip().lower() in {"", "nan", "null", "none"}
                else value.strip()
                for value in row
            )
            batch.append(values)

            if len(batch) >= BATCH_SIZE:
                cursor.executemany(insert_sql, batch)
                connection.commit()
                inserted_count += len(batch)
                batch.clear()

        if batch:
            cursor.executemany(insert_sql, batch)
            connection.commit()
            inserted_count += len(batch)

    print(f"{table_name}: 导入 {inserted_count:,} 行")
    return inserted_count


def main() -> None:
    missing_files = [
        RAW_DIR / filename
        for filename, _ in IMPORT_FILES
        if not (RAW_DIR / filename).is_file()
    ]
    if missing_files:
        missing_names = ", ".join(path.name for path in missing_files)
        raise FileNotFoundError(
            f"在 {RAW_DIR} 中找不到这些文件：{missing_names}"
        )

    password = getpass("输入 MySQL root 密码：")
    connection = None

    try:
        connection = mysql.connector.connect(
            host=HOST,
            port=PORT,
            user=USER,
            password=password,
            database=DATABASE,
        )
        cursor = connection.cursor()

        # 这是首次导入脚本：如果表已有数据就停止，避免重复插入
        nonempty_tables = []
        for _, table_name in IMPORT_FILES:
            cursor.execute(f"SELECT COUNT(*) FROM `{table_name}`")
            row_count = cursor.fetchone()[0]
            if row_count > 0:
                nonempty_tables.append(f"{table_name} ({row_count:,} 行)")

        if nonempty_tables:
            raise RuntimeError(
                "以下表已有数据，脚本为避免重复导入已停止："
                + ", ".join(nonempty_tables)
            )

        total = 0
        for filename, table_name in IMPORT_FILES:
            total += load_csv(
                cursor,
                connection,
                RAW_DIR / filename,
                table_name,
            )

        print(f"导入完成，共导入 {total:,} 行。")

    except Exception:
        if connection is not None and connection.is_connected():
            connection.rollback()
        raise

    finally:
        if connection is not None and connection.is_connected():
            connection.close()


if __name__ == "__main__":
    main()