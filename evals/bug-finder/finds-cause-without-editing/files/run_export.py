"""使い方: python3 run_export.py [出力先]"""

import sys

from exporter.export import export_csv
from exporter.source import all_customers
from exporter.summary import summarize

if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "customers.csv"
    rows = all_customers()
    export_csv(rows, out)
    print(summarize(rows))
    print(f"wrote {out}")
