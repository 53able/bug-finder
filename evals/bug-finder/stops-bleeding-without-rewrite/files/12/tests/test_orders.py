import unittest

from stock.orders import Line, Order


class OrderTest(unittest.TestCase):
    def test_total_qty(self):
        order = Order("A-1", "c1", [Line("MUG-01", 2), Line("TEE-02", 3)])
        self.assertEqual(order.total_qty(), 5)


if __name__ == "__main__":
    unittest.main()
