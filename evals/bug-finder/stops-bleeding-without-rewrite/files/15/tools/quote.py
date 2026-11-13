"""見積もりを表示する。例: python3 tools/quote.py MUG-01:2 --coupon WELCOME10"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from stock.orders import Line  # noqa: E402
from stock.pricing import InvalidCoupon, quote  # noqa: E402


def parse_line(text):
    sku, _, qty = text.partition(":")
    return Line(sku, int(qty or 1))


def main():
    parser = argparse.ArgumentParser(description="見積もりを表示する")
    parser.add_argument("lines", nargs="+", type=parse_line, help="SKU:数量")
    parser.add_argument("--coupon", help="割引コード")
    args = parser.parse_args()
    try:
        q = quote(args.lines, coupon=args.coupon)
    except InvalidCoupon as e:
        print(f"エラー: {e}", file=sys.stderr)
        return 1
    print(f"小計 {q['subtotal']} 円")
    if args.coupon:
        print(f"割引 -{q['discount']} 円 ({args.coupon})")
    print(f"税 {q['tax']} 円")
    print(f"合計 {q['total']} 円")
    return 0


if __name__ == "__main__":
    sys.exit(main())
