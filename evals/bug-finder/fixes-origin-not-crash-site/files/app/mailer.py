"""請求のお知らせメールを作る。本文はテンプレートから生成する。"""

from pathlib import Path

import minitpl

from .config import ROOT
from .formatting import due_date, period_label, yen
from .invoice import build_invoice

TEMPLATE_PATH = ROOT / "templates" / "email.tpl"


def build_context(tenant):
    mail = tenant.settings["mail"]
    data = build_invoice(tenant)
    return {
        "customer": tenant.name,
        "greeting": mail["greeting"],
        "period_label": data["period"],
        "plan_label": data["charge"]["label"],
        "seats": tenant.seats,
        "total": yen(data["total"], data["unit"]),
        "due": data["due"],
        "footer_text": mail["footer_text"],
        "reply_to": mail["reply_to"],
        "sender_name": mail["sender_name"],
    }


def build_email(tenant):
    """件名・宛先・本文を持つ辞書を返す。"""
    context = build_context(tenant)
    body = minitpl.render_file(TEMPLATE_PATH, context)
    return {
        "to": tenant.contact_email,
        "subject": "【%s】%sのご請求" % (context["sender_name"], context["period_label"]),
        "body": body,
    }


def format_email(email):
    return "To: %s\nSubject: %s\n\n%s" % (email["to"], email["subject"], email["body"])


def spool(email, outbox_dir, tenant_id):
    """送信待ちのメールをファイルに書き出す。"""
    outbox = Path(outbox_dir)
    outbox.mkdir(parents=True, exist_ok=True)
    path = outbox / ("%s.eml" % tenant_id)
    path.write_text(format_email(email), encoding="utf-8")
    return path
