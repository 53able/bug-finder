# stock

在庫の引当サービス。注文を受け付けて在庫を確保し、倉庫へ出庫を指示する。

- `stock/inventory.py`: 在庫数と引当
- `stock/allocator.py`: 注文の引当
- `stock/service.py`: 注文の受付
- `stock/pricing.py`: 見積もり

## 開発

- テスト: `python3 -m unittest discover -s tests -t .`
- 注文の流れの再現: `python3 tools/simulate_orders.py`
