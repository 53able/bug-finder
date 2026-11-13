"""注文の引当。明細ごとに在庫を確保し、倉庫へ出庫指示を出す。"""

from stock.inventory import OutOfStock
from stock.warehouse import WarehouseError

MAX_ATTEMPTS = 3


class AllocationFailed(Exception):
    """引当できなかった。確保済みの分は解放してある。"""


def _reserve_all(inventory, lines):
    hold_ids = []
    try:
        for line in lines:
            hold_ids.append(inventory.reserve(line.sku, line.qty))
    except OutOfStock:
        for hold_id in hold_ids:
            inventory.release(hold_id)
        raise
    return hold_ids


def allocate_order(inventory, warehouse, order):
    """注文を引き当てて出庫指示番号を返す。倉庫のエラーは数回まで試し直す。"""
    last_error = None
    for _ in range(MAX_ATTEMPTS):
        try:
            hold_ids = _reserve_all(inventory, order.lines)
        except OutOfStock as e:
            raise AllocationFailed(str(e)) from e
        try:
            return warehouse.request_pick(order.order_id, order.lines)
        except WarehouseError as e:
            last_error = e
            for hold_id in hold_ids:
                inventory.release(hold_id)
    raise AllocationFailed(f"{order.order_id}: 倉庫に指示できない ({last_error})")
