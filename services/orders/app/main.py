import os
import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from prometheus_fastapi_instrumentator import Instrumentator
import sqlalchemy as sa

app = FastAPI(title="orders")
Instrumentator().instrument(app).expose(app)

# Kubernetes internal DNS: <svc>.<namespace>.svc.cluster.local
USERS_URL = os.getenv("USERS_URL", "http://users.default.svc.cluster.local")
engine = sa.create_engine(os.getenv("DATABASE_URL", "sqlite:///./orders.db"))
meta = sa.MetaData()
orders = sa.Table("orders", meta, sa.Column("id", sa.Integer, primary_key=True),
                  sa.Column("user_id", sa.Integer, nullable=False),
                  sa.Column("item", sa.String(200), nullable=False),
                  sa.Column("qty", sa.Integer, nullable=False))
meta.create_all(engine)

class OrderIn(BaseModel):
    user_id: int
    item: str
    qty: int = 1

@app.get("/healthz")
def healthz(): return {"status": "ok"}

@app.post("/orders", status_code=201)
def create_order(o: OrderIn):
    try:
        r = httpx.get(f"{USERS_URL}/users/{o.user_id}", timeout=3)
    except httpx.HTTPError:
        raise HTTPException(503, "users service unavailable")
    if r.status_code == 404: raise HTTPException(400, "unknown user")
    with engine.begin() as c:
        res = c.execute(orders.insert().values(**o.model_dump()))
    return {"id": res.inserted_primary_key[0], **o.model_dump()}

@app.get("/orders/{oid}")
def get_order(oid: int):
    with engine.connect() as c:
        row = c.execute(orders.select().where(orders.c.id == oid)).mappings().first()
    if not row: raise HTTPException(404, "not found")
    return dict(row)
