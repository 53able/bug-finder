import unittest

from app.formatting import due_date, period_label, yen


class FormattingTest(unittest.TestCase):
    def test_yen(self):
        self.assertEqual(yen(1234567), "1,234,567円")
        self.assertEqual(yen(0), "0円")

    def test_period_label(self):
        self.assertEqual(period_label("2025-10"), "2025年10月")
        self.assertEqual(period_label("2025-01"), "2025年1月")

    def test_due_date_counts_from_month_end(self):
        self.assertEqual(due_date("2025-10", 30), "2025年11月30日")

    def test_due_date_crosses_year_end(self):
        self.assertEqual(due_date("2025-12", 14), "2026年1月14日")


if __name__ == "__main__":
    unittest.main()
