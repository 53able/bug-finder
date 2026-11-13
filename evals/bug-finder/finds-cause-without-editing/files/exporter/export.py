"""顧客一覧の CSV 出力。"""

import csv

from exporter.source import fetch_page

HEADER = ["id", "name", "plan"]


def export_csv(rows, path, page_size=100):
    pages = len(rows) // page_size
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(HEADER)
        for page in range(pages):
            for row in fetch_page(rows, page, page_size):
                writer.writerow([row[key] for key in HEADER])
    return path
