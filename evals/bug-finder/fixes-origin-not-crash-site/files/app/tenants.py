"""テナントの読み込み。既定の設定にテナントごとの上書きを重ねる。"""

from dataclasses import dataclass, field

from .config import load_json, merge_settings


@dataclass
class Tenant:
    id: str
    name: str
    plan: str
    seats: int
    contact_email: str
    settings: dict = field(default_factory=dict)


def build_tenant(record, defaults):
    settings = merge_settings(defaults, record.get("overrides", {}))
    return Tenant(
        id=record["id"],
        name=record["name"],
        plan=record["plan"],
        seats=record["seats"],
        contact_email=record["contact_email"],
        settings=settings,
    )


def load_tenants():
    defaults = load_json("defaults.json")
    return [build_tenant(r, defaults) for r in load_json("tenants.json")]


def find_tenant(tenant_id):
    for tenant in load_tenants():
        if tenant.id == tenant_id:
            return tenant
    raise KeyError("テナントが見つかりません: %s" % tenant_id)
