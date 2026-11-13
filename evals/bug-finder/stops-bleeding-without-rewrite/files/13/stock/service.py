"""注文の受付。引当はキューに積み、ワーカーが処理する。"""

from stock.dispatcher import Dispatcher
from stock.jobqueue import JobQueue
from stock.retry import RetryPolicy
from stock.worker import AllocationWorker, order_payload

WORKERS = 2


class OrderService:
    def __init__(self, inventory, warehouse, clock):
        self.inventory = inventory
        self.warehouse = warehouse
        self.clock = clock
        self.accepted = {}
        self.rejected = {}
        self.queue = JobQueue(clock)
        workers = [
            AllocationWorker(f"worker-{i}", self.queue, inventory, warehouse,
                             RetryPolicy(), self._done, self._failed)
            for i in range(1, WORKERS + 1)
        ]
        self.dispatcher = Dispatcher(self.queue, workers)

    def _done(self, order_id, pick_id):
        self.rejected.pop(order_id, None)
        self.accepted[order_id] = pick_id

    def _failed(self, order_id, reason):
        self.rejected[order_id] = reason

    def place_order(self, order):
        """注文を受け付ける。引当まで済んだら出庫指示番号を、まだなら None を返す。"""
        self.queue.put(order_payload(order))
        self.dispatcher.pump()
        return self.accepted.get(order.order_id)
