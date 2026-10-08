# Databricks notebook source
# MAGIC %sql
# MAGIC CREATE OR REPLACE FUNCTION `d4001-centralus-tdvip-liquidityrisk`.alfa_core.call_governed_api(
# MAGIC     api_name STRING,
# MAGIC     req_path STRING,
# MAGIC     registry_json STRING
# MAGIC )
# MAGIC RETURNS STRING
# MAGIC LANGUAGE PYTHON
# MAGIC AS $$
# MAGIC import json
# MAGIC import requests
# MAGIC
# MAGIC registry = json.loads(registry_json)
# MAGIC
# MAGIC if api_name not in registry:
# MAGIC     return f"ERROR: API '{api_name}' is not registered"
# MAGIC
# MAGIC api_config = registry[api_name]
# MAGIC base_url = api_config["base_url"]
# MAGIC paths = api_config["paths"]
# MAGIC
# MAGIC path_only = req_path.split("?")[0] if "?" in req_path else req_path
# MAGIC
# MAGIC path_approved = False
# MAGIC for path_rule in paths:
# MAGIC     if path_rule["type"] == "EXACT" and req_path == path_rule["value"]:
# MAGIC         path_approved = True
# MAGIC         break
# MAGIC     elif path_rule["type"] == "PREFIX" and path_only.startswith(path_rule["value"]):
# MAGIC         path_approved = True
# MAGIC         break
# MAGIC
# MAGIC if not path_approved:
# MAGIC     return f"ERROR: Path '{req_path}' is not approved for API '{api_name}'"
# MAGIC
# MAGIC full_url = base_url + req_path
# MAGIC try:
# MAGIC     r = requests.get(full_url, timeout=10, verify=False)
# MAGIC     return str(r.status_code)
# MAGIC except Exception as e:
# MAGIC     return f"ERROR: {str(e)}"
# MAGIC $$

# COMMAND ----------

# MAGIC %skip
# MAGIC %sql
# MAGIC CREATE TABLE IF NOT EXISTS `d4001-centralus-tdvip-liquidityrisk`.alfa_core.api_governance_registry (
# MAGIC   api_name STRING NOT NULL,
# MAGIC   base_url STRING NOT NULL,
# MAGIC   path_url_type STRING NOT NULL,
# MAGIC   path_value STRING NOT NULL,
# MAGIC   approved BOOLEAN NOT NULL,
# MAGIC   owner_team STRING,
# MAGIC   notes STRING
# MAGIC )

# COMMAND ----------

# MAGIC %skip
# MAGIC %sql
# MAGIC INSERT INTO `d4001-centralus-tdvip-liquidityrisk`.alfa_core.api_governance_registry
# MAGIC   (api_name, base_url, path_url_type, path_value, approved, owner_team, notes)
# MAGIC VALUES
# MAGIC   ('postman_mock', 'https://f0ea5df4-0ce9-45dc-9a86-06fce04fdb58.mock.pstmn.io', 'EXACT',  '/',                     true, 'TD', 'Root endpoint'),
# MAGIC   ('postman_mock', 'https://f0ea5df4-0ce9-45dc-9a86-06fce04fdb58.mock.pstmn.io', 'PREFIX', '/udf-demo',             true, 'TD', 'Allow child paths'),
# MAGIC   ('dremio_td',    'https://infoplatform-dremio-dev.corp.tdsecurities.com',       'EXACT',  '/',                     true, 'TD', 'Root endpoint'),
# MAGIC   ('dremio_td',    'https://infoplatform-dremio-dev.corp.tdsecurities.com',       'PREFIX', '/space/ACES.SMRTS',     true, 'TD', 'Allow child paths'),
# MAGIC   ('repo_td',      'https://repo.td.com',                                         'EXACT',  '/',                     true, 'TD', 'Root endpoint'),
# MAGIC   ('repo_td',      'https://repo.td.com',                                         'EXACT',  '/#browse/search/maven', true, 'TD', 'Allow child paths');

# COMMAND ----------

spark.sql("""
MERGE INTO `d4001-centralus-tdvip-liquidityrisk`.alfa_core.api_governance_registry tgt
USING (
    SELECT 'postman_mock' AS api_name,
           'https://f0ea5df4-0ce9-45dc-9a86-06fce04fdb58.mock.pstmn.io' AS base_url,
           'EXACT'   AS path_url_type,
           '/'       AS path_value,
           true      AS approved,
           'TD'      AS owner_team,
           'Root endpoint' AS notes
    UNION ALL
    SELECT 'postman_mock',
           'https://f0ea5df4-0ce9-45dc-9a86-06fce04fdb58.mock.pstmn.io',
           'PREFIX',
           '/udf-demo',
           true,
           'TD',
           'Allow child paths'
    UNION ALL
    SELECT 'dremio_td',
           'https://infoplatform-dremio-dev.corp.tdsecurities.com',
           'EXACT',
           '/',
           true,
           'TD',
           'Root endpoint'
    UNION ALL
    SELECT 'dremio_td',
           'https://infoplatform-dremio-dev.corp.tdsecurities.com',
           'PREFIX',
           '/space/ACES.SMRTS',
           true,
           'TD',
           'Allow child paths'
    UNION ALL
    SELECT 'repo_td',
           'https://repo.td.com',
           'EXACT',
           '/',
           true,
           'TD',
           'Root endpoint'
    UNION ALL
    SELECT 'repo_td',
           'https://repo.td.com',
           'EXACT',
           '/#browse/search/maven',
           true,
           'TD',
           'Allow child paths'
) src
ON tgt.api_name = src.api_name
AND tgt.base_url = src.base_url
AND tgt.path_url_type = src.path_url_type
AND tgt.path_value = src.path_value
WHEN NOT MATCHED THEN
  INSERT (api_name, base_url, path_url_type, path_value, approved, owner_team, notes)
  VALUES (
    src.api_name,
    src.base_url,
    src.path_url_type,
    src.path_value,
    src.approved,
    src.owner_team,
    src.notes
  )
""")

# COMMAND ----------

from pyspark.sql import functions as F
import json

governance_df = spark.table("`d4001-centralus-tdvip-liquidityrisk`.alfa_core.api_governance_registry")
governance_data = governance_df.filter(F.col("approved") == True).collect()

governance_registry = {}
for row in governance_data:
    api = row["api_name"]
    if api not in governance_registry:
        governance_registry[api] = {
            "base_url": row["base_url"],
            "paths": []
        }
    governance_registry[api]["paths"].append({
        "type": row["path_url_type"],
        "value": row["path_value"]
    })

governance_json = json.dumps(governance_registry)

def process_csv_api_calls_governed(
    csv_path: str,
    api_name: str,
    endpoint: str,
    params: dict | None = None,
    output_table: str | None = None
):
    df = spark.read.csv(csv_path, header=True, inferSchema=True)

    req_path = F.lit(endpoint)

    if params:
        param_parts = []
        for param_name, config in params.items():
            if config["type"] == "column":
                value_expr = F.col(config["value"]).cast("string")
                value_expr = F.regexp_replace(value_expr, " ", "%20")
            elif config["type"] == "literal":
                value_expr = F.lit(str(config["value"]))
            else:
                raise ValueError(f"Unsupported param type for {param_name}: {config['type']}")
            param_parts.append(F.concat(F.lit(f"{param_name}="), value_expr))

        if param_parts:
            query_expr = param_parts[0]
            for p in param_parts[1:]:
                query_expr = F.concat(query_expr, F.lit("&"), p)
            req_path = F.concat(F.lit(endpoint), F.lit("?"), query_expr)

    df = df.withColumn("req_path", req_path)

    result_df = df.withColumn(
        "api_result",
        F.expr(f"""
            `d4001-centralus-tdvip-liquidityrisk`.alfa_core.call_governed_api(
                '{api_name}',
                req_path,
                '{governance_json.replace("'", "''")}'
            )
        """)
    )

    return result_df

# COMMAND ----------

# MAGIC %skip
# MAGIC result_df = process_csv_api_calls_governed(
# MAGIC     csv_path="/Volumes/d4001-centralus-tdvip-liquidityrisk/alfa_core/alfa_core_volume/function/sample_limit_energy_updated.csv",
# MAGIC     api_name="dremio_td",
# MAGIC     endpoint="/",
# MAGIC     params={
# MAGIC         "limit_id": {"type": "column", "value": "Limit ID"},
# MAGIC         "limit_name": {"type": "column", "value": "Limit Name"},
# MAGIC         "is_active": {"type": "column", "value": "Is Active"},
# MAGIC         "env": {"type": "literal", "value": "dev"}
# MAGIC     }
# MAGIC )
# MAGIC
# MAGIC display(result_df)

# COMMAND ----------

result_df = process_csv_api_calls_governed(
    csv_path="/Volumes/d4001-centralus-tdvip-liquidityrisk/alfa_core/alfa_core_volume/function/sample_limit_energy_updated.csv",
    api_name="dremio_td",
    endpoint="/",
    params={
    }
)

display(result_df)
