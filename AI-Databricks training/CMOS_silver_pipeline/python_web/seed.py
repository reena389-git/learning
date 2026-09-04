# SEED — put our own dataset into the database so the server has data to serve.
# Run this ONCE before starting the server:  python seed.py
from app import engine, InstrumentRow, Base
from sqlalchemy.orm import Session
from sqlalchemy import select

Base.metadata.create_all(engine)

DATA = [
    ("AAPL",   "Apple Inc",        "equity",    "USD", 195.2),
    ("MSFT",   "Microsoft Corp",   "equity",    "USD", 420.1),
    ("UST10Y", "US Treasury 10Y",  "bond",      "USD", 98.7),
    ("EURUSD", "Euro / US Dollar", "fx",        "USD", 1.09),
    ("GOLD",   "Gold Spot",        "commodity", "USD", 2400.0),
]

with Session(engine) as s:
    for sym, name, cls, ccy, px in DATA:
        if not s.scalar(select(InstrumentRow).where(InstrumentRow.symbol == sym)):
            s.add(InstrumentRow(symbol=sym, name=name, asset_class=cls, currency=ccy, price=px))
    s.commit()
    print("seeded:", s.scalars(select(InstrumentRow.symbol)).all())
