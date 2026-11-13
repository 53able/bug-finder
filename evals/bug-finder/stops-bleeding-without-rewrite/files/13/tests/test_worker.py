import unittest

from stock.clock import ManualClock
from stock.dispatcher import Dispatcher
from stock.inventory import Inventory
from stock.jobqueue import JobQueue
from stock.orders import Line, Order
from stock.retry import RetryPolicy
from stock.warehouse import RecordingWarehouse, WarehouseError
from stock.worker import AllocationWorker, order_payload


class FlakyWarehouse(RecordingWarehouse):
    def __init__(self, failures):
        super().__init__()
        self.failures = failures

    def request_pick(self, order_id, lines):
        if self.failures > 0:
            self.failures -= 1
            raise WarehouseError("503")
        return super().request_pick(order_id, lines)


class WorkerTest(unittest.TestCase):
    def setUp(self):
        self.clock = ManualClock(start=1000)
        self.inv = Inventory(self.clock)
        self.inv.receive("MUG-01", 3)
        self.queue = JobQueue(self.clock)
        self.done, self.failed = {}, {}

    def run_order(self, warehouse, qty, policy=RetryPolicy(base_delay=1, max_delay=1)):
        worker = AllocationWorker("w1", self.queue, self.inv, warehouse, policy,
                                  self.done.__setitem__, self.failed.__setitem__)
        dispatcher = Dispatcher(self.queue, [worker])
        self.queue.put(order_payload(Order("A-1", "c1", [Line("MUG-01", qty)])))
        while self.queue.pending():
            dispatcher.pump()
            self.clock.advance(1)
        return dispatcher.outcomes

    def test_allocates(self):
        self.run_order(RecordingWarehouse(), 2)
        self.assertEqual(self.done, {"A-1": "PICK-00001"})
        self.assertEqual(self.inv.available("MUG-01"), 1)

    def test_out_of_stock_is_rejected(self):
        self.run_order(RecordingWarehouse(), 4)
        self.assertIn("A-1", self.failed)
        self.assertEqual(self.inv.available("MUG-01"), 3)

    def test_warehouse_error_is_retried(self):
        outcomes = self.run_order(FlakyWarehouse(failures=2), 1)
        self.assertEqual(self.done, {"A-1": "PICK-00001"})
        self.assertEqual(self.inv.available("MUG-01"), 2)
        self.assertEqual(outcomes["retry"], 2)


if __name__ == "__main__":
    unittest.main()
