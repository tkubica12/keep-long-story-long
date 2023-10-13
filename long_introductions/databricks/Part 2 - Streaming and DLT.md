# Part 2 - Streaming and DLT

1.  Streaming with DLT - Ingesting
```python
# Get configuration parameters and secrets
storage_account_name = ""
eventhub_namespace_name = ""
eventhub_pages_key = ""
eventhub_stars_key = ""
azuresql_password = ""
sql_server_name = ""

# Imports
import dlt
from pyspark.sql.functions import *
from pyspark.sql.types import *

# Users from Azure Storage
data_path_users = f"abfss://bronze@{storage_account_name}.dfs.core.windows.net/users/"
checkpoint_path_users = f"abfss://bronze@{storage_account_name}.dfs.core.windows.net/_checkpoint/streamusers"

@dlt.table()
def stream_users():
  return (
    spark.readStream.format("cloudFiles")
     .option("cloudFiles.format", "json")
     .option("cloudFiles.schemaLocation", checkpoint_path_users)
     .load(data_path_users)
 )

# VIP Users from Azure Storage
data_path_vipusers = f"abfss://bronze@{storage_account_name}.dfs.core.windows.net/vipusers/"
checkpoint_path_vipusers = f"abfss://bronze@{storage_account_name}.dfs.core.windows.net/_checkpoint/vipusers"

@dlt.table()
def stream_vipusers():
  return (
    spark.readStream.format("cloudFiles")
     .option("cloudFiles.format", "json")
     .option("cloudFiles.schemaLocation", checkpoint_path_vipusers)
     .load(data_path_vipusers)
 )

# Products from Azure Storage
data_path_products = f"abfss://bronze@{storage_account_name}.dfs.core.windows.net/products/"
checkpoint_path_products = f"abfss://bronze@{storage_account_name}.dfs.core.windows.net/_checkpoint/products"

@dlt.table()
def stream_products():
  return (
    spark.readStream.format("cloudFiles")
     .option("cloudFiles.format", "json")
     .option("cloudFiles.schemaLocation", checkpoint_path_products)
     .load(data_path_products)
 )

# Pageviews from Kafka
@dlt.table
def stream_pageviews():
    connection = f'kafkashaded.org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="Endpoint=sb://{eventhub_namespace_name}.servicebus.windows.net/;SharedAccessKeyName=pageviewsReceiver;SharedAccessKey={eventhub_pages_key}";'

    kafka_options = {
     "kafka.bootstrap.servers": f"{eventhub_namespace_name}.servicebus.windows.net:9093",
     "kafka.sasl.mechanism": "PLAIN",
     "kafka.security.protocol": "SASL_SSL",
     "kafka.request.timeout.ms": "60000",
     "kafka.session.timeout.ms": "30000",
     "startingOffsets": "earliest",
     "kafka.sasl.jaas.config": connection,
     "subscribe": "pageviews",
      }
    return spark.readStream.format("kafka").options(**kafka_options).load()

# Stars from Kafka
@dlt.table
def stream_stars():
    connection = f'kafkashaded.org.apache.kafka.common.security.plain.PlainLoginModule required username="$ConnectionString" password="Endpoint=sb://{eventhub_namespace_name}.servicebus.windows.net/;SharedAccessKeyName=starsReceiver;SharedAccessKey={eventhub_stars_key}";'

    kafka_options = {
     "kafka.bootstrap.servers": f"{eventhub_namespace_name}.servicebus.windows.net:9093",
     "kafka.sasl.mechanism": "PLAIN",
     "kafka.security.protocol": "SASL_SSL",
     "kafka.request.timeout.ms": "60000",
     "kafka.session.timeout.ms": "30000",
     "startingOffsets": "earliest",
     "kafka.sasl.jaas.config": connection,
     "subscribe": "stars",
      }
    return spark.readStream.format("kafka").options(**kafka_options).load()

# Orders and items from Azure SQL Database
url = f"jdbc:sqlserver://{sql_server_name}.database.windows.net:1433;database=orders"

@dlt.table(
  spark_conf={"pipelines.trigger.interval" : "60 seconds"}
)
def stream_orders():
  return (
    spark.read.format("jdbc")
     .option("url", url)
     .option("database", "orders")
     .option("dbtable", "orders")
     .option("user", "tomas")
     .option("password", azuresql_password)
     .load()
 )

@dlt.table(
  spark_conf={"pipelines.trigger.interval" : "60 seconds"}
)
def stream_items():
  return (
    spark.read.format("jdbc")
     .option("url", url)
     .option("database", "orders")
     .option("dbtable", "items")
     .option("user", "tomas")
     .option("password", azuresql_password)
     .load()
 )
```

See tables in catalog and check data there. Note history on pageviews (a lot of changes - logs) and also check data pageviews - not readable, parsing is needed.

2.  Streaming with DLT - Parsing
```sql
CREATE OR REFRESH STREAMING LIVE TABLE parsed_pageviews
AS SELECT timestamp,
  get_json_object(CAST(value AS string), '$.user_id') AS user_id,
  get_json_object(CAST(value AS string), '$.http_method') AS http_method,
  get_json_object(CAST(value AS string), '$.uri') AS uri,
  get_json_object(CAST(value AS string), '$.client_ip') AS client_ip,
  get_json_object(CAST(value AS string), '$.user_agent') AS user_agent, 
  get_json_object(CAST(value AS string), '$.latency') AS latency 
FROM STREAM(live.stream_pageviews);

CREATE OR REFRESH STREAMING LIVE TABLE parsed_stars
AS SELECT timestamp,
  get_json_object(CAST(value AS string), '$.user_id') AS user_id,
  get_json_object(CAST(value AS string), '$.stars') AS stars
FROM STREAM(live.stream_stars);
```

3.  Streaming with DLT - Processing
This is typical silver tier processing:
- Preprocessed table with pageviews that experienced high latency
- Correlate stars events from user that happen within 15 minutes of pageview -> users that gave stars after viewing our pages
  
```sql
CREATE OR REFRESH STREAMING LIVE TABLE high_latency
AS SELECT *
FROM STREAM(live.parsed_pageviews)
WHERE latency > 4000;

CREATE OR REFRESH STREAMING LIVE TABLE pageviews_stars_correlation
AS SELECT live.parsed_pageviews.user_id,
          live.parsed_pageviews.http_method,
          live.parsed_pageviews.uri,
          live.parsed_pageviews.client_ip,
          live.parsed_pageviews.user_agent,
          live.parsed_pageviews.latency,
          live.parsed_stars.stars
FROM STREAM(live.parsed_pageviews)
JOIN STREAM(live.parsed_stars)
  ON live.parsed_pageviews.user_id = live.parsed_stars.user_id
  AND DATEDIFF(MINUTE, live.parsed_pageviews.timestamp,live.parsed_stars.timestamp) BETWEEN 0 AND 15 ;
```

4.  Streaming with DLT - Gold table
```sql
CREATE OR REFRESH LIVE TABLE engagements
AS
SELECT users.id, 
  users.user_name, 
  users.city,
  COUNT(pageviews.user_id) AS pageviews, 
  COUNT(aggregatedOrders.userId) AS orders,
  SUM(aggregatedOrders.orderValue) AS total_orders_value,
  AVG(aggregatedOrders.orderValue) AS avg_order_value,
  SUM(aggregatedOrders.itemsCount) AS total_items,
  AVG(stars.stars) AS avg_stars,
  iff(isnull(vipusers.id), false, true) AS is_vip
FROM live.stream_users AS users
LEFT JOIN live.parsed_pageviews AS pageviews 
ON users.id = pageviews.user_id
LEFT JOIN (
  SELECT orders.userId, orders.orderValue, orders.orderId, COUNT(items.orderId) AS itemsCount
  FROM live.stream_orders AS orders
  LEFT JOIN live.stream_items AS items
  ON orders.orderId = items.orderId
  GROUP BY orders.userId, orders.orderValue, orders.orderId) AS aggregatedOrders
ON users.id = aggregatedOrders.userId
LEFT JOIN live.parsed_stars AS stars ON users.id = stars.user_id
LEFT JOIN live.stream_vipusers AS vipusers ON users.id = vipusers.id
GROUP BY users.id, users.user_name, users.city, is_vip;
```