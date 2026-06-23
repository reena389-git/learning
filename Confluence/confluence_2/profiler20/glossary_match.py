# Databricks notebook source
# MAGIC %md
# MAGIC # glossary_match  —  name → glossary matcher (companion module)
# MAGIC
# MAGIC `%run` this notebook from the profiler to get two functions in scope:
# MAGIC
# MAGIC - `GLOSSARY = load_glossary(catalog, schema, table)` — reads the glossary Delta table once, returns an index
# MAGIC - `match_field(physical_name, GLOSSARY)` — returns a dict: token, canonical_term, owner_domain, party, product_class, im_vm, is_currency
# MAGIC
# MAGIC It deliberately holds **no Spark state** beyond the one read in `load_glossary`, and no widgets — so it is safe to `%run` repeatedly. Matching logic is pure-Python (driver-side); the only standard library used is `re`.

# COMMAND ----------

import re

# ---- qualifier vocabularies -------------------------------------------------
_PARTY = {"cp": "CP", "cpty": "CP", "counterparty": "CP",
          "td": "TD", "principal": "TD", "prc": "TD"}
_PRODCLASS = {"ir": "IR", "irs": "IR", "iro": "IR", "ccs": "CCS", "fx": "FX",
              "fxo": "FXO", "eqd": "EQD", "crd": "CRD", "com": "COMM", "comm": "COMM",
              "ngas": "NGAS", "oes": "OES", "bo": "BO", "pm": "PM", "derv": "DERV",
              "xnet": "ALL"}
_DROP = {"im", "vm", "ccy", "currency", "values", "value", "base", "fixed",
         "amount", "amt", "id", "code", "name", "1", "2", "first", "leg", "second",
         "reporting", "total", "external"}
_SPLITMAP = {"immta": ["im", "mta"], "immtaccy": ["im", "mta"]}
_SYN = {"nominal": "notional", "movement": "asset_movement", "call": "margin_call",
        "action": "call_status", "model": "im_calc_method", "instrument": "isda_product_type",
        "instrumenttype": "isda_product_type", "applicableagreements": "agreement_type",
        "asset": "asset_holding", "valuation": "valuation_date", "underlyings": "underlying",
        "equity": "asset_class", "cash": "asset_class", "govvies": "asset_class"}


def _norm(s):
    return re.sub(r"[^a-z0-9]", "", (s or "").lower())


def build_glossary_index(records):
    """records: iterable of dicts with at least token, canonical_term, owner_domain,
    source_standard, definition, also_seen_as. Returns {'alias':..., 'meta':...}."""
    alias, meta = {}, {}
    for r in records:
        tok = r["token"]
        meta[tok] = r
        keys = [tok] + [a for a in (r.get("also_seen_as") or "").split(",") if a]
        for k in keys:
            kk = _norm(k)
            if kk and kk not in alias:
                alias[kk] = tok
    return {"alias": alias, "meta": meta}


def load_glossary(catalog, schema, table, status_filter=None):
    """Read the glossary Delta table and build the match index.
    status_filter e.g. 'approved' to match only signed-off terms (None = all)."""
    fqn = f"`{catalog}`.`{schema}`.`{table}`"
    df = spark.table(fqn)  # noqa: F821  (spark provided by Databricks)
    if status_filter:
        df = df.filter(df.status == status_filter)
    records = [row.asDict() for row in df.collect()]
    idx = build_glossary_index(records)
    idx["_source"] = fqn
    idx["_count"] = len(records)
    print(f"[glossary_match] loaded {len(records)} terms from {fqn}"
          + (f" (status={status_filter})" if status_filter else ""))
    return idx


def _tokenize(leaf):
    leaf = leaf.split(".")[-1]
    s = re.sub(r"([a-z0-9])([A-Z])", r"\1 \2", leaf)          # camelCase
    s = re.sub(r"([A-Z]+)([A-Z][a-z])", r"\1 \2", s)          # ACRONYMCase
    toks = [t.lower() for t in re.split(r"[ _\-\.\[\]/]+", s) if t]
    out = []
    for t in toks:
        out += _SPLITMAP.get(t, [t])
    return out


def match_field(name, glossary):
    """Map a physical column/field name to a glossary term.
    Returns a dict; token == '' means no match (caller should flag for review)."""
    alias, meta = glossary["alias"], glossary["meta"]
    toks = _tokenize(name)
    party = next((_PARTY[t] for t in toks if t in _PARTY), "")
    prod = next((_PRODCLASS[t] for t in toks if t in _PRODCLASS), "")
    mv = "IM" if "im" in toks else ("VM" if "vm" in toks else "")
    is_ccy = ("ccy" in toks or "currency" in toks)

    cand = []
    whole = "".join(toks)
    if whole in alias:
        cand.append(alias[whole])
    core = [t for t in toks if t not in _PARTY and t not in _DROP]
    joined = "".join(core)
    if joined and joined in alias:
        cand.append(alias[joined])
    if joined in _SYN:
        cand.append(_SYN[joined])
    for t in core:
        if t in alias:
            cand.append(alias[t])
        elif t in _SYN:
            cand.append(_SYN[t])
    seen, ordered = set(), []
    for c in cand:
        if c not in seen:
            seen.add(c); ordered.append(c)
    token = ordered[0] if ordered else ""

    m = meta.get(token, {})
    return {
        "physical_field": name,
        "glossary_token": token,
        "canonical_term": m.get("canonical_term", ""),
        "business_definition": m.get("definition", ""),
        "owner_domain": m.get("owner_domain", ""),
        "source_standard": m.get("source_standard", ""),
        "status": m.get("status", ""),
        "party": party,
        "product_class": prod,
        "im_vm": mv,
        "is_currency": "ccy" if is_ccy else "",
        "matched": bool(token),
    }


print("[glossary_match] ready — load_glossary(catalog, schema, table), match_field(name, glossary)")
