import unittest

from stock.clock import ManualClock
from stock.inventory import Inventory
from stock.orders import Line, Order
from stock.service import OrderService
from stock.warehouse import RecordingWarehouse


class OrderServiceTest(unittest.TestCase):
    def setUp(self):
        clock = ManualClock()
        self.inv = Inventory(clock)
        self.inv.receive("MUG-01", 3)
        self.wh = RecordingWarehouse()
        self.service = OrderService(self.inv, self.wh, clock)

    def test_accepts_orders_while_stock_lasts(self):
        for i in range(4):
            self.service.place_order(Order(f"A-{i}", "c1", [Line("MUG-01", 1)]))
        self.assertEqual(sorted(self.service.accepted), ["A-0", "A-1", "A-2"])
        self.assertIn("A-3", self.service.rejected)
        self.assertEqual(self.inv.available("MUG-01"), 0)
        self.assertEqual(len(self.wh.picks), 3)

    def test_invalid_order_is_rejected_before_allocation(self):
        self.assertIsNone(self.service.place_order(Order("A-9", "c1", [Line("MUG-01", 0)])))
        self.assertIn("数量", self.service.rejected["A-9"])
        self.assertEqual(self.inv.available("MUG-01"), 3)
        self.assertEqual(self.wh.picks, [])


if __name__ == "__main__":
    unittest.main()
