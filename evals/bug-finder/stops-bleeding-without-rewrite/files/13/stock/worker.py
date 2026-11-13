"""引当ジョブを処理するワーカー。"""

from stock.inventory import OutOfStock
from stock.orders import Line
from stock.warehouse import WarehouseError


def order_payload(order):
    """注文をキューに積める形 (文字列と数値だけ) にする。"""
    return {
        "order_id": order.order_id,
        "customer": order.customer,
        "lines": [[line.sku, line.qty] for line in order.lines],
    }


class AllocationWorker:
    def __init__(self, name, queue, inventory, warehouse, retry_policy, on_done, on_failed):
        self.name = name
        self.queue = queue
        self.inventory = inventory
        self.warehouse = warehouse
        self.retry_policy = retry_policy
        self.on_done = on_done
        self.on_failed = on_failed

    def _release(self, hold_ids):
        for hold_id in hold_ids:
            self.inventory.release(hold_id)

    def process(self, lease):
        """ジョブを 1 つ処理して結果 (done / rejected / retry / failed / lost) を返す。"""
        order_id = lease.payload["order_id"]
        lines = [Line(sku, qty) for sku, qty in lease.payload["lines"]]
        hold_ids = []
        try:
            for line in lines:
                hold_ids.append(self.inventory.reserve(line.sku, line.qty))
        except OutOfStock as e:
            self._release(hold_ids)
            self.queue.ack(lease)
            self.on_failed(order_id, str(e))
            return "rejected"
        try:
            pick_id = self.warehouse.request_pick(order_id, lines)
        except WarehouseError as e:
            self._release(hold_ids)
            if self.retry_policy.should_retry(lease.attempts):
                self.queue.retry_later(lease, self.retry_policy.delay(lease.attempts))
                return "retry"
            self.queue.ack(lease)
            self.on_failed(order_id, f"{order_id}: 倉庫に指示できない ({e})")
            return "failed"
        if not self.queue.ack(lease):
            # 処理権は他のワーカーに移っている。完了の通知はそちらに任せる。
            return "lost"
        self.on_done(order_id, pick_id)
        return "done"
