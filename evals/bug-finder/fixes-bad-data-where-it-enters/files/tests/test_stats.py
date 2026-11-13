import unittest

from sales.loader import load_sales
from sales.stats import by_store, total_amount


class StatsTest(unittest.TestCase):
    def setUp(self):
        self.records = load_sales("data/sales.csv")

    def test_total(self):
        self.assertEqual(total_amount(self.records), 18437)

    def test_by_store(self):
        self.assertEqual(by_store(self.records)["hakata"], 15300)


if __name__ == "__main__":
    unittest.main()
