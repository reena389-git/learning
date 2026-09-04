# CLIENT — the OTHER side of the API. Talks to the running server over HTTP.
# Start the server first (uvicorn app:app --reload), then in a new terminal: python client.py
import httpx

BASE = "http://127.0.0.1:8000"

# 1) GET the whole list (request -> response)
resp = httpx.get(f"{BASE}/instruments")
print("GET /instruments ->", resp.status_code)
for inst in resp.json():
    print(f"   {inst['symbol']:8} {inst['asset_class']:10} {inst['price']}")

# 2) GET one by symbol
resp = httpx.get(f"{BASE}/instruments/AAPL")
print("\nGET /instruments/AAPL ->", resp.status_code, resp.json())

# 3) POST a new instrument (send a JSON body; server validates + stores)
new = {"symbol": "BTCUSD", "name": "Bitcoin", "asset_class": "fx", "currency": "USD", "price": 68000.0}
resp = httpx.post(f"{BASE}/instruments", json=new)
print("\nPOST /instruments ->", resp.status_code, resp.json())

# 4) Try an invalid POST and see the 422 the contract produces
bad = {"symbol": "OOPS", "name": "Oops", "asset_class": "crypto", "currency": "USD", "price": -1}
resp = httpx.post(f"{BASE}/instruments", json=bad)
print("\nPOST invalid ->", resp.status_code)
if resp.status_code == 422:
    for e in resp.json()["detail"]:
        print("   rejected:", e["loc"][-1], "-", e["msg"])
