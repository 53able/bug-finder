import unittest

from stock.orders import Line, Order


class OrderTest(unittest.TestCase):
    def test_total_qty(self):
        order = Order("A-1", "c1", [Line("MUG-01", 2), Line("TEE-02", 3)])
        self.assertEqual(order.total_qty(), 5)

    def test_problem(self):
        self.assertIsNone(Order("A-1", "c1", [Line("MUG-01", 2)]).problem())
        self.assertIn("明細がない", Order("A-2", "c1").problem())
        self.assertIn("数量", Order("A-3", "c1", [Line("MUG-01", 0)]).problem())
        self.assertIn("上限", Order("A-4", "c1", [Line("MUG-01", 21)]).problem())


if __name__ == "__main__":
    unittest.main()
