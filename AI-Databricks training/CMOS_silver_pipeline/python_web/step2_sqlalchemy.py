# STEP 2 — SQLAlchemy on its own: define a table, write rows, read them back.
# (This is the database, before any web/server.)
from sqlalchemy import create_engine, String, Float, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session

engine = create_engine("sqlite:///demo.db")     # a local file database

class Base(DeclarativeBase):
    pass

class Instrument(Base):
    __tablename__ = "instruments"
    id:          Mapped[int]   = mapped_column(primary_key=True)
    symbol:      Mapped[str]   = mapped_column(String, unique=True)
    name:        Mapped[str]   = mapped_column(String)
    asset_class: Mapped[str]   = mapped_column(String)
    price:       Mapped[float] = mapped_column(Float)

Base.metadata.create_all(engine)                # CREATE TABLE (if needed)

with Session(engine) as s:                      # WRITE
    s.add(Instrument(symbol="AAPL", name="Apple Inc", asset_class="equity", price=195.2))
    s.add(Instrument(symbol="UST10Y", name="US Treasury 10Y", asset_class="bond", price=98.7))
    s.commit()

with Session(engine) as s:                      # READ
    rows = s.scalars(select(Instrument)).all()
    for r in rows:
        print(f"{r.id}: {r.symbol:8} {r.asset_class:8} {r.price}")
    one = s.scalar(select(Instrument).where(Instrument.symbol == "AAPL"))
    print("looked up AAPL ->", one.name)
