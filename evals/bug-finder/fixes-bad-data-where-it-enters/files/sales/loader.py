"""売上 CSV の読み込み。"""

import csv


def load_sales(path):
    records = []
    with open(path, newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            records.append(
                {
                    "id": row["id"].strip(),
                    "store": row["store"].strip(),
                    "amount": row["amount"].strip(),
                    "quantity": int(row["quantity"]),
                }
            )
    return records
