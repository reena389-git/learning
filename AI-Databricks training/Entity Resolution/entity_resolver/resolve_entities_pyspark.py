"""
Config-driven Entity Resolver — Databricks / PySpark production version.
Cascade: normalize -> standardize tokens -> [exact -> parent_match -> address_match
-> corroborated -> fuzzy(Jaro-Winkler) -> semantic(composite embedding)] -> connected-components
-> assign canonical + confidence + match_tier -> QUARANTINE the uncertain.
Source table is NEVER modified (audit). Output = a governed crosswalk + a quarantine table.

REUSABLE: to resolve a different entity (counterparty, security, customer), change CONFIG only.
Per-entity you supply: (a) column roles, (b) a token synonym dict, (c) which fields corroborate.
"""
from pyspark.sql import functions as F, types as T
import re

# ============================ CONFIG (the only per-entity part) ============================
CONFIG = dict(
  source_table   = "`d4001-centralus-tdvip-creditrisk`.cmos_core.issuer_messy",
  crosswalk_table= "`d4001-centralus-tdvip-creditrisk`.cmos_core.issuer_crosswalk",
  quarantine_tbl = "`d4001-centralus-tdvip-creditrisk`.cmos_core.issuer_quarantine",
  id_col="record_id", name_col="issuer_name",
  parent_col="parent_name", address_col="address", city_col="city", country_col="country",
  composite_fields=["issuer_name","parent_name","city","country"],   # your Solr concat trick
  block_on="country",   # BLOCKING key: only compare rows sharing this (scales O(n^2)->manageable)
  thr=dict(corroborate_name=0.85, fuzzy_name=0.92, parent_match=0.93, address_match=0.90, semantic=0.72),
)
SYN = {"LIMITED":"LTD","LTD.":"LTD","&":"AND","CORPORATION":"CORP","CO.":"CO","COMPANY":"CO",
       "INTERNATIONAL":"INTL","BK":"BANK","A.G.":"AG","N.A.":"NA","INCORPORATED":"INC","INC.":"INC"}

# ============================ UDFs (normalize / standardize / composite) ============================
def _norm(s):
    if s is None: return ""
    s=re.sub(r"[^A-Z0-9 ]"," ",str(s).upper().replace("&"," AND "));  return re.sub(r"\s+"," ",s).strip()
def _std(s):
    return " ".join(SYN.get(t,t) for t in _norm(s).split())
norm_udf=F.udf(_norm,T.StringType()); std_udf=F.udf(_std,T.StringType())

def _jw(a,b):
    # Jaro-Winkler; use jellyfish if available, else a light fallback
    try:
        import jellyfish; return float(jellyfish.jaro_winkler_similarity(a or "", b or ""))
    except Exception:
        from difflib import SequenceMatcher; return SequenceMatcher(None,a or "",b or "").ratio()
jw_udf=F.udf(_jw,T.DoubleType())

def build_composite(df):
    cols=[F.when(F.col(f).isNotNull() & (F.length(F.col(f))>0),
                 F.concat(F.lit(f.split('_')[0]+": "), norm_udf(F.col(f)))) for f in CONFIG["composite_fields"]]
    return df.withColumn("_comp", F.concat_ws(" | ", *cols))

# ============================ MAIN ============================
def resolve(spark):
    C=CONFIG; thr=C["thr"]
    df = spark.table(C["source_table"]) \
        .withColumn("_nm", norm_udf(F.col(C["name_col"]))) \
        .withColumn("_std", std_udf(F.col(C["name_col"])))
    df = build_composite(df)
    # ---- SEMANTIC EMBEDDING (composite -> vector). In prod use a real model: ----
    #   from databricks.vector_search or ai_query() with an embedding endpoint, OR
    #   Databricks AI Search index on _comp. Here left as a hook (tier is optional).
    #   embed_udf = ...  ; df = df.withColumn("_emb", embed_udf("_comp"))
    #
    # ---- BLOCKING: self-join only within the same block key (scales) ----
    a=df.alias("a"); b=df.alias("b")
    pairs = a.join(b, (F.col(f"a.{C['block_on']}")==F.col(f"b.{C['block_on']}")) &
                       (F.col(f"a.{C['id_col']}") < F.col(f"b.{C['id_col']}")))
    # ---- cascade scoring (expressed as columns) ----
    ns = jw_udf(F.col("a._std"), F.col("b._std"))
    pj = jw_udf(std_udf(F.col(f"a.{C['parent_col']}")), std_udf(F.col(f"b.{C['parent_col']}")))
    aj = jw_udf(std_udf(F.col(f"a.{C['address_col']}")), std_udf(F.col(f"b.{C['address_col']}")))
    both=lambda col: F.col(f"a.{col}").isNotNull() & F.col(f"b.{col}").isNotNull()
    country_contradict = both(C['country_col']) & (norm_udf(F.col(f"a.{C['country_col']}"))!=norm_udf(F.col(f"b.{C['country_col']}")))
    parent_contradict  = both(C['parent_col']) & (pj < F.lit(0.80))
    veto = country_contradict | parent_contradict
    parent_agree = both(C['parent_col']) & (pj>=thr["parent_match"])
    addr_agree   = both(C['address_col']) & (aj>=thr["address_match"])
    tier = (F.when(veto, F.lit(None))
             .when(F.col("a._nm")==F.col("b._nm"), F.lit("exact"))
             .when(F.col("a._std")==F.col("b._std"), F.lit("standardized"))
             .when(parent_agree, F.lit("parent_match"))
             .when(addr_agree & (ns>=0.6), F.lit("address_match"))
             .when((ns>=thr["corroborate_name"]) & (parent_agree|addr_agree), F.lit("corroborated"))
             .when(ns>=thr["fuzzy_name"], F.lit("fuzzy"))
             # semantic tier would go here once _emb is populated (cosine>=thr['semantic'])
             .otherwise(F.lit(None)))
    conf = (F.when(tier=="exact",1.00).when(tier=="standardized",0.97).when(tier=="parent_match",0.92)
             .when(tier=="corroborated",0.93).when(tier=="address_match",0.88).when(tier=="fuzzy",0.80)
             .when(tier=="semantic",0.70).otherwise(F.lit(0.0)))
    edges = pairs.select(F.col(f"a.{C['id_col']}").alias("src"), F.col(f"b.{C['id_col']}").alias("dst"),
                         tier.alias("tier"), conf.alias("conf")).where(F.col("tier").isNotNull())

    # ---- connected components via GraphFrames (cluster the matched pairs) ----
    from graphframes import GraphFrame
    verts = df.select(F.col(C['id_col']).alias("id"), C['name_col'])
    cc = GraphFrame(verts, edges.select("src","dst")).connectedComponents()  # requires spark.checkpointDir set

    # best tier/conf per record
    best = (edges.select(F.col("src").alias("id"),"tier","conf")
            .unionByName(edges.select(F.col("dst").alias("id"),"tier","conf"))
            .groupBy("id").agg(F.max("conf").alias("confidence"),
                               F.first("tier", ignorenulls=True).alias("match_tier")))
    joined = cc.join(best,"id","left").join(df.select(F.col(C['id_col']).alias("id"),C['name_col']),"id")

    # canonical name per component = most frequent name
    w = F.count("*").over(__import__("pyspark").sql.Window.partitionBy("component", C['name_col']))
    canon = (joined.withColumn("cnt", w)
             .withColumn("rk", F.row_number().over(__import__("pyspark").sql.Window.partitionBy("component").orderBy(F.desc("cnt"))))
             .where(F.col("rk")==1).select("component", F.col(C['name_col']).alias("canonical")))
    result = joined.join(canon,"component") \
        .withColumn("size", F.count("*").over(__import__("pyspark").sql.Window.partitionBy("component"))) \
        .withColumn("status", F.when((F.col("size")>1) & F.col("match_tier").isin("exact","standardized","parent_match","address_match","corroborated","fuzzy") & (F.col("confidence")>=0.80), F.lit("resolved")).otherwise(F.lit("quarantine"))) \
        .withColumn("assigned_canonical", F.when(F.col("status")=="resolved", F.col("canonical")))

    crosswalk = result.select(F.col("id").alias(C['id_col']), C['name_col'], "assigned_canonical","match_tier","confidence","status")
    crosswalk.where("status='resolved'").write.mode("overwrite").saveAsTable(C["crosswalk_table"])
    crosswalk.where("status='quarantine'").write.mode("overwrite").saveAsTable(C["quarantine_tbl"])
    return crosswalk

# spark.sparkContext.setCheckpointDir("/tmp/cc"); resolve(spark).show()
