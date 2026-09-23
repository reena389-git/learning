# Databricks notebook source
# =============================================================================
#  01 - SETUP: generate small, deliberately MESSY synthetic data
# =============================================================================
#  WHY messy on purpose: clean data teaches nothing. We inject exactly the
#  problems this prototype needs to exercise: nulls in required fields, an
#  out-of-range value, an orphan foreign key (customer with no match), and a
#  NEW COLUMN that only appears in "wave 2" of transactions (to trigger schema
#  evolution). Two waves of transaction files let us prove Auto Loader only
#  picks up what's NEW on the second run (incremental behaviour).
#
#  Two tables, matching a generic fact/dimension shape so this is reusable
#  for any domain, not tied to a specific story:
#    customers    (small dimension table)
#    transactions (fact table; wave 1 + wave 2 files)
#
#  Adjust VOLUME_PATH to a Unity Catalog volume you can write to.
# =============================================================================

# COMMAND ----------
VOLUME_PATH = "/Volumes/workspace/default/perf_prototype_raw"   # <-- adjust if needed
dbutils.fs.mkdirs(VOLUME_PATH)
dbutils.fs.mkdirs(f"{VOLUME_PATH}/customers")
dbutils.fs.mkdirs(f"{VOLUME_PATH}/transactions")

# COMMAND ----------
# ---- customers.csv : the dimension table --------------------------------
# WHY these specific flaws: a NULL customer_name (data-quality check target),
# and a duplicate customer_id (join/uniqueness discussion target).
import csv, random
random.seed(7)

customers_rows = [
    ("C001", "Aria Chen", "West"),
    ("C002", "Miles Osei", "East"),
    ("C003", None, "West"),            # <-- NULL name: DQ target
    ("C004", "Priya Nair", "South"),
    ("C005", "Jon Alvarez", "East"),
    ("C001", "Aria Chen", "West"),      # <-- duplicate customer_id: uniqueness target
]

with open("/tmp/customers.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["customer_id", "customer_name", "region"])
    w.writerows(customers_rows)

dbutils.fs.cp("file:/tmp/customers.csv", f"{VOLUME_PATH}/customers/customers.csv")
print("customers.csv written:", len(customers_rows), "rows (1 null name, 1 duplicate id)")

# COMMAND ----------
# ---- transactions_wave1.csv : first arrival --------------------------------
# WHY these flaws: a NULL customer_id (can't even attempt a join), a negative
# amount (an out-of-range value a DQ expectation should catch), and one
# ORPHAN customer_id ("C999") that doesn't exist in customers at all - this is
# what Module-04's join-reject capture is built to catch.
txn_wave1 = [
    ("T1001", "C001", 120.50, "2026-09-01", "COMPLETE"),
    ("T1002", "C002",  75.00, "2026-09-01", "COMPLETE"),
    ("T1003", None,    40.00, "2026-09-01", "COMPLETE"),   # NULL customer_id
    ("T1004", "C003", -15.00, "2026-09-02", "COMPLETE"),   # negative amount
    ("T1005", "C999", 200.00, "2026-09-02", "COMPLETE"),   # orphan customer (no match)
    ("T1006", "C004",  60.25, "2026-09-02", "PENDING"),
]
with open("/tmp/transactions_wave1.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["transaction_id", "customer_id", "amount", "transaction_date", "status"])
    w.writerows(txn_wave1)
dbutils.fs.cp("file:/tmp/transactions_wave1.csv", f"{VOLUME_PATH}/transactions/wave1.csv")
print("wave1.csv written:", len(txn_wave1), "rows")

# COMMAND ----------
# ---- transactions_wave2.csv : SECOND arrival, with a NEW COLUMN -----------
# WHY a new column here specifically: this is the schema-evolution trigger.
# 'channel' does not exist in wave1 - Auto Loader must decide how to react
# (addNewColumns / rescue / fail) when this file lands.
txn_wave2 = [
    ("T2001", "C001",  99.99, "2026-09-03", "COMPLETE", "ONLINE"),
    ("T2002", "C005", 150.00, "2026-09-03", "COMPLETE", "STORE"),
    ("T2003", "C002",  10.00, "2026-09-03", "COMPLETE", "ONLINE"),
]
with open("/tmp/transactions_wave2.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["transaction_id", "customer_id", "amount", "transaction_date", "status", "channel"])
    w.writerows(txn_wave2)
# NOTE: we do NOT copy wave2 into the volume yet - Module 02 copies it in
# partway through, to prove Auto Loader only picks up what's new.
print("wave2.csv staged at /tmp (Module 02 will land it partway through)")

# COMMAND ----------
print("Setup complete.")
print("  customers:", f"{VOLUME_PATH}/customers/customers.csv")
print("  transactions wave 1 (already landed):", f"{VOLUME_PATH}/transactions/wave1.csv")
print("  transactions wave 2 (staged, not landed yet): /tmp/transactions_wave2.csv")
