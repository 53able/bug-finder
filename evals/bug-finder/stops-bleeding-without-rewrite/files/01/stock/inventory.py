"""在庫数と引当 (hold) を管理する。"""

from dataclasses import dataclass


class OutOfStock(Exception):
    """引き当てられる在庫が足りない。"""


@dataclass
class Hold:
    hold_id: int
    sku: str
    qty: int
    held_at: float


class Inventory:
    def __init__(self, clock):
        self._clock = clock
        self._on_hand = {}
        self._holds = {}
        self._next_hold_id = 1

    def receive(self, sku, qty):
        if qty <= 0:
            raise ValueError("入荷数は 1 以上")
        self._on_hand[sku] = self._on_hand.get(sku, 0) + qty

    def on_hand(self, sku):
        return self._on_hand.get(sku, 0)

    def held(self, sku):
        return sum(h.qty for h in self._holds.values() if h.sku == sku)

    def available(self, sku):
        return self.on_hand(sku) - self.held(sku)

    def reserve(self, sku, qty):
        """在庫を確保して hold の番号を返す。"""
        if qty <= 0:
            raise ValueError("引当数は 1 以上")
        if self.available(sku) < qty:
            raise OutOfStock(f"{sku}: 残り {self.available(sku)} に対して {qty}")
        hold = Hold(self._next_hold_id, sku, qty, self._clock.now())
        self._holds[hold.hold_id] = hold
        self._next_hold_id += 1
        return hold.hold_id

    def release(self, hold_id):
        self._holds.pop(hold_id, None)
