"""注文のデータ。"""

from dataclasses import dataclass, field


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
