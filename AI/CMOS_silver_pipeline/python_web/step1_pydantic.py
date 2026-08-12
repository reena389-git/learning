# STEP 1 — Pydantic on its own: define a data shape, validate it.
# (This is the "contract" idea, before any web/server.)
from pydantic import BaseModel, field_validator, ValidationError

ALLOWED = {"equity", "bond", "fx", "commodity"}

class Instrument(BaseModel):
    symbol: str
    name: str
    asset_class: str
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

good = {"symbol": "AAPL", "name": "Apple Inc", "asset_class": "equity", "price": 195.2}
print("VALID   ->", Instrument(**good))                 # parses + validates
print("as dict ->", Instrument(**good).model_dump())    # back to a plain dict

bad = {"symbol": "BAD", "name": "Nope", "asset_class": "crypto", "price": -5}
try:
    Instrument(**bad)
except ValidationError as e:
    print("REJECTED:")
    for err in e.errors():
        print("   -", err["loc"][-1], ":", err["msg"])
