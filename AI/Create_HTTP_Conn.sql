# SQL Databricks to create connection
# bearer token was created using workspace Secret

CREATE CONNECTION finnhub_conn
TYPE HTTP
OPTIONS (host 'https://finnhub.io',
  port '443',
  base_path '/api/v1',
  bearer_token 'finnhub-api:api_key'
);

show connections

#. Finnhub not a good example since it uses api key, and databricks sends the bearer token in the header and finnhub rejects it as a malformed message

SELECT http_request(
  conn => 'finnhub_conn',
  method => 'GET',
  path => concat('/quote?symbol=AAPL&token=', secret('finnhub','api_key'))
).text AS quote;
