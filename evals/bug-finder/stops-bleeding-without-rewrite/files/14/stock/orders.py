"""注文のデータ。"""

from dataclasses import dataclass, field

MAX_QTY_PER_ORDER = 20


@dataclass(frozen=True)
class Line:
    sku: str
    qty: int


@dataclass
class Order:
    order_id: str
    customer: str
    lines: list = field(default_factory=list)

    def total_qty(self):
        return sum(line.qty for line in self.lines)

    def problem(self):
        """受け付けられない注文なら理由を、問題がなければ None を返す。"""
        if not self.lines:
            return f"{self.order_id}: 明細がない"
        for line in self.lines:
            if line.qty < 1:
                return f"{self.order_id}: {line.sku} の数量が 1 未満 ({line.qty})"
        if self.total_qty() > MAX_QTY_PER_ORDER:
            return f"{self.order_id}: 1 注文の上限 {MAX_QTY_PER_ORDER} 個を超えている"
        return None
