import csv
import os
import tempfile
import unittest

from exporter.export import export_csv
from exporter.source import all_customers


class ExportTest(unittest.TestCase):
    def test_exports_all_rows(self):
        rows = all_customers(300)
        with tempfile.TemporaryDirectory() as tmp:
            path = export_csv(rows, os.path.join(tmp, "out.csv"))
            with open(path, newline="", encoding="utf-8") as f:
                exported = list(csv.reader(f))
        self.assertEqual(len(exported) - 1, 300)


if __name__ == "__main__":
    unittest.main()
