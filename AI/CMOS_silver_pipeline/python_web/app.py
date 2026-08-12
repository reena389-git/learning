# ============================================================
#  Instrument Reference API  —  the whole stack in one file
#  Run with:  uvicorn app:app --reload
#  Then open: http://127.0.0.1:8000/docs
# ============================================================
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, field_validator, ConfigDict
from sqlalchemy import create_engine, String, Float, select
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, Session

# ---- 1. SQLAlchemy: the DATABASE layer -----------------------------
# create_engine = the connection to the DB. Here a local SQLite file.
engine = create_engine("sqlite:///instruments.db")

class Base(DeclarativeBase):
    pass

class InstrumentRow(Base):                       # one Python class == one DB table
    __tablename__ = "instruments"
    id:          Mapped[int]   = mapped_column(primary_key=True)
    symbol:      Mapped[str]   = mapped_column(String, unique=True)
    name:        Mapped[str]   = mapped_column(String)
    asset_class: Mapped[str]   = mapped_column(String)
    currency:    Mapped[str]   = mapped_column(String)
    price:       Mapped[float] = mapped_column(Float)

Base.metadata.create_all(engine)                 # create the table if it doesn't exist

# ---- 2. Pydantic: the API's DATA CONTRACTS -------------------------
ALLOWED = {"equity", "bond", "fx", "commodity"}

class InstrumentIn(BaseModel):                   # what a client SENDS (no id yet)
    symbol: str
    name: str
    asset_class: str
    currency: str
    price: float

    @field_validator("asset_class")
    @classmethod
    def known_class(cls, v):
        if v not in ALLOWED:
            raise ValueError(f"asset_class must be one of {sorted(ALLOWED)}")
        return v

    @field_validator("price")
    @classmethod
    def non_negative(cls, v):
        if v < 0:
            raise ValueError("price must be >= 0")
        return v

class InstrumentOut(InstrumentIn):               # what the API RETURNS (adds id)
    id: int
    model_config = ConfigDict(from_attributes=True)   # can read straight from a DB row

# ---- 3. one DB session per request (a "dependency") ----------------
def get_db():
    with Session(engine) as session:
        yield session

# ---- 4. FastAPI: the SERVER (endpoints) ----------------------------
app = FastAPI(title="Instrument Reference API", version="1.0")

@app.get("/instruments", response_model=list[InstrumentOut])       # READ many
def list_instruments(db: Session = Depends(get_db)):
    return db.scalars(select(InstrumentRow)).all()

@app.get("/instruments/{symbol}", response_model=InstrumentOut)    # READ one
def get_instrument(symbol: str, db: Session = Depends(get_db)):
    row = db.scalar(select(InstrumentRow).where(InstrumentRow.symbol == symbol))
    if row is None:
        raise HTTPException(status_code=404, detail="instrument not found")
    return row

@app.post("/instruments", response_model=InstrumentOut, status_code=201)  # CREATE
def create_instrument(payload: InstrumentIn, db: Session = Depends(get_db)):
    exists = db.scalar(select(InstrumentRow).where(InstrumentRow.symbol == payload.symbol))
    if exists:
        raise HTTPException(status_code=409, detail="symbol already exists")
    row = InstrumentRow(**payload.model_dump())   # Pydantic -> DB row
    db.add(row); db.commit(); db.refresh(row)
    return row
