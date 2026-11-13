import unittest

from stock.clock import ManualClock
from stock.inventory import Inventory, OutOfStock


class InventoryTest(unittest.TestCase):
    def setUp(self):
        self.clock = ManualClock(start=100)
        self.inv = Inventory(self.clock)
        self.inv.receive("MUG-01", 5)

    def test_reserve_reduces_available(self):
        self.inv.reserve("MUG-01", 2)
        self.assertEqual(self.inv.available("MUG-01"), 3)
        self.assertEqual(self.inv.on_hand("MUG-01"), 5)

    def test_release_restores_available(self):
        hold_id = self.inv.reserve("MUG-01", 2)
        self.inv.release(hold_id)
        self.assertEqual(self.inv.available("MUG-01"), 5)

    def test_out_of_stock(self):
        self.inv.reserve("MUG-01", 4)
        with self.assertRaises(OutOfStock):
            self.inv.reserve("MUG-01", 2)


if __name__ == "__main__":
    unittest.main()
