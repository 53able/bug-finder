"""注文の受付。"""

from stock.allocator import AllocationFailed, allocate_order


class OrderService:
    def __init__(self, inventory, warehouse, clock):
        self.inventory = inventory
        self.warehouse = warehouse
        self.clock = clock
        self.accepted = {}
        self.rejected = {}

    def place_order(self, order):
        """注文を受け付ける。引き当てられたら出庫指示番号を返す。"""
        try:
            pick_id = allocate_order(self.inventory, self.warehouse, order)
        except AllocationFailed as e:
            self.rejected[order.order_id] = str(e)
            return None
        self.accepted[order.order_id] = pick_id
        return pick_id
