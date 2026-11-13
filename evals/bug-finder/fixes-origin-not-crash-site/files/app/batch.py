"""夜間バッチ。全テナントのメールと請求書を作る。

  python3 -m app.batch             メールを outbox/ に書き出す
  python3 -m app.batch --dry-run   書き出さず、メールと請求書を標準出力に出す

生成に失敗したテナントがあっても、残りのテナントの処理は続ける。
失敗の詳細は標準エラー出力に出し、1 件でも失敗があれば終了コード 1 で終わる。
"""

import argparse
import sys
import traceback

from .config import ROOT
from .invoice import render_invoice_text
from .mailer import build_email, format_email, spool
from .tenants import load_tenants


def _email_text(tenant):
    return format_email(build_email(tenant))


OUTPUTS = (("email", _email_text), ("invoice", render_invoice_text))


def render_all(tenants):
    """(テナント ID, 種類, テキスト, エラー) のリストを返す。"""
    results = []
    for tenant in tenants:
        for kind, build in OUTPUTS:
            try:
                results.append((tenant.id, kind, build(tenant), None))
            except Exception:
                results.append((tenant.id, kind, None, traceback.format_exc()))
    return results


def main(argv=None):
    parser = argparse.ArgumentParser(prog="python3 -m app.batch")
    parser.add_argument("--dry-run", action="store_true", help="書き出さず標準出力に出す")
    args = parser.parse_args(argv)

    tenants = load_tenants()
    failed = 0
    for tenant_id, kind, text, error in render_all(tenants):
        if error:
            failed += 1
            print("=== %s %s FAILED ===" % (tenant_id, kind))
            sys.stderr.write("[%s] %s の生成に失敗しました\n%s" % (tenant_id, kind, error))
        else:
            print("=== %s %s ===" % (tenant_id, kind))
            print(text)

    if not args.dry_run:
        for tenant in tenants:
            try:
                spool(build_email(tenant), ROOT / "outbox", tenant.id)
            except Exception:
                pass
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
