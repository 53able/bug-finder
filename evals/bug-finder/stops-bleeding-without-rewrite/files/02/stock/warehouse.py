"""倉庫システムへの出庫指示。本番は HTTP クライアントを使う。ここでは指示を記録するだけ。"""


class WarehouseError(Exception):
    """倉庫システムが指示を受け付けなかった。"""


class RecordingWarehouse:
    def __init__(self):
        self.picks = []

    def request_pick(self, order_id, lines):
        """出庫を指示して指示番号を返す。"""
        self.picks.append((order_id, tuple((line.sku, line.qty) for line in lines)))
        return f"PICK-{len(self.picks):05d}"
