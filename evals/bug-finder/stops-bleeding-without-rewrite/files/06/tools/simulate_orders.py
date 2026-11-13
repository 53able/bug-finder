"""注文の流れを手元で再現する。

使い方: python3 tools/simulate_orders.py [--slow-seconds 秒]
倉庫 API は、注文によって最初の応答に時間がかかることがある (既定値は本番で観測した値)。
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from stock.clock import ManualClock  # noqa: E402
from stock.inventory import Inventory  # noqa: E402
from stock.orders import Line, Order  # noqa: E402
from stock.service import OrderService  # noqa: E402
from stock.warehouse import RecordingWarehouse  # noqa: E402

SKU = "MUG-01"
STOCK = 10
ORDERS = 6
SLOW_ORDERS = {"A-1002", "A-1005"}
SLOW_SECONDS = 45


class SlowFirstCallWarehouse(RecordingWarehouse):
    """指定した注文だけ、最初の出庫指示の応答に時間がかかる。"""

    def __init__(self, clock, slow_orders, delay):
        super().__init__()
        self.clock = clock
        self.slow_orders = set(slow_orders)
        self.delay = delay
        self._seen = set()

    def request_pick(self, order_id, lines):
        if order_id in self.slow_orders and order_id not in self._seen:
            self._seen.add(order_id)
            self.clock.advance(self.delay)
        return super().request_pick(order_id, lines)


def main():
    parser = argparse.ArgumentParser(description="注文の流れを手元で再現する")
    parser.add_argument("--slow-seconds", type=float, default=SLOW_SECONDS, help="遅い応答にかかる秒数")
    args = parser.parse_args()
    clock = ManualClock(start=1_700_000_000)
    inventory = Inventory(clock)
    inventory.receive(SKU, STOCK)
    warehouse = SlowFirstCallWarehouse(clock, SLOW_ORDERS, args.slow_seconds)
    service = OrderService(inventory, warehouse, clock)
    orders = [Order(f"A-{1000 + i}", f"customer-{i}", [Line(SKU, 1)]) for i in range(1, ORDERS + 1)]
    for order in orders:
        service.place_order(order)
    print(f"入荷 {STOCK} 個 / 注文 {len(orders)} 個 (各 1 個)")
    print(f"受付 {len(service.accepted)} 件 / 拒否 {len(service.rejected)} 件 / 倉庫への出庫指示 {len(warehouse.picks)} 件")
    print(f"{SKU} の残り: {inventory.available(SKU)} 個")


if __name__ == "__main__":
    main()
