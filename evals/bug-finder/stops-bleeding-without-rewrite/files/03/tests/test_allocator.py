import unittest

from stock.allocator import AllocationFailed, allocate_order
from stock.clock import ManualClock
from stock.inventory import Inventory
from stock.orders import Line, Order
from stock.warehouse import RecordingWarehouse


class AllocatorTest(unittest.TestCase):
    def setUp(self):
        self.inv = Inventory(ManualClock())
        self.inv.receive("MUG-01", 3)
        self.inv.receive("TEE-02", 1)
        self.wh = RecordingWarehouse()

    def test_allocates_all_lines(self):
        order = Order("A-1", "c1", [Line("MUG-01", 2), Line("TEE-02", 1)])
        self.assertEqual(allocate_order(self.inv, self.wh, order), "PICK-00001")
        self.assertEqual(self.inv.available("MUG-01"), 1)
        self.assertEqual(self.inv.available("TEE-02"), 0)

    def test_partial_shortage_releases_everything(self):
        order = Order("A-2", "c1", [Line("MUG-01", 1), Line("TEE-02", 2)])
        with self.assertRaises(AllocationFailed):
            allocate_order(self.inv, self.wh, order)
        self.assertEqual(self.inv.available("MUG-01"), 3)
        self.assertEqual(self.wh.picks, [])


if __name__ == "__main__":
    unittest.main()
