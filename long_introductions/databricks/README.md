# Long Introduction to Databricks

1. Create workspace
2. Create storage, databricks container and bronze container and upload JSON
```json
{"name": "Martin", "department": "Marketing", "age": 37}
{"name": "Jane", "department": "CEO", "age": 44}
{"name": "Eva", "department": "Sales", "age": 23}
{"name": "Charles", "department": "Finance", "age": 62}
```

1. Create access connector and give it access to storage
2. Create metastore
3. Create external location
4. Create and start SQL warehouse
5. Create and start Compute
6. Short SQL demo
```sql
SELECT *
FROM JSON.`abfss://bronze@tomasdatalake541.dfs.core.windows.net/firsttry/data.json`

CREATE VIEW myview AS
SELECT *
FROM json.`abfss://bronze@tomasdatalake541.dfs.core.windows.net/firsttry/data.json`;

SELECT * FROM myview

SELECT *
FROM myview
WHERE age > 33

SELECT department, AVG(age) AS AverageAge
FROM myviewttry/data.json
GROUP BY department
```
7.  Short PySpark demo
```python
df = spark.read \
    .format('json') \
    .load('abfss://bronze@tomasdatalake541.dfs.core.windows.net/firsttry/data.json')

df.printSchema()

df.display()

from pyspark.sql.functions import col
df.filter(col("age") > 30).display()

df.groupBy("department").avg("age").display()
```
8.  Short Pandas demo
```python
pdf = df.toPandas()
pdf[pdf.age > 30].display()
pdf.groupby(by=['department']).mean().display()
```

8. Store query, add description, create alert
   
9.  Create dashboard - table and Bar chart

10. Parquet and Delta
```sql
-- Create Parquet based table in external location
-- We will keep it in bronze tier as we are not doing any transformations, cleanup or evaluation
-- We will use external location so we can managed storage and folders ourselves
CREATE TABLE parquetexample
USING parquet
LOCATION 'abfss://bronze@tomasdatalake541.dfs.core.windows.net/parquetexample'
AS
SELECT *
FROM json.`abfss://bronze@tomasdatalake541.dfs.core.windows.net/firsttry/data.json`;

-- Check the table
SELECT * FROM parquetexample

-- Go to Azure storage and observe files there

-- Insert new row
INSERT INTO parquetexample
VALUES (50, "Innovation", "Marek")

-- Check the table
SELECT * FROM parquetexample

-- Go to Azure storage and observe files there again, see new parquet file
-- Go to Catalog UI and see history is not available, this is not transactional


-- Now we will create Delta table in bronze tier
CREATE TABLE deltaexample
USING delta
LOCATION 'abfss://bronze@tomasdatalake541.dfs.core.windows.net/deltaexample'
AS
SELECT *
FROM json.`abfss://bronze@tomasdatalake541.dfs.core.windows.net/firsttry/data.json`;

-- Check the table
SELECT * FROM deltaexample

-- Insert new row
INSERT INTO deltaexample
VALUES (50, "Innovation", "Marek")

-- Check the table
SELECT * FROM deltaexample

-- Go to Azure storage and observe files there again, see new transactions in delta log

-- Delete some data
DELETE FROM deltaexample
WHERE department == "Marketing"

-- Check the table
SELECT * FROM deltaexample

-- Check table history (log), similar view can be seen in UI
DESCRIBE HISTORY deltaexample

-- We can see state of data as of some version
SELECT * FROM deltaexample VERSION AS OF 0

-- Let's restore the data
RESTORE deltaexample VERSION AS OF 1;

SELECT * FROM deltaexample;

-- Note that restore is just another event in log, nothing is lost
DESCRIBE HISTORY deltaexample;

-- To speed up queries we can optimize files structure (right-size files)
OPTIMIZE deltaexample;

-- To reclaim space after optimization, we can use VACUUM command
-- By default it will keep 7 days of history
-- There is safety check that forbids going lower than that. 
-- Here are commands to override, but those are not working on SQL warehouse (you can use compute cluster for it)
USE main.default;
SET spark.databricks.delta.retentionDurationCheck.enabled=false;
VACUUM deltaexample RETAIN 0 HOURS;

-- Go to Azure storage and observe files there again
```

11. Comment deep and shallow (copy on write) clones - currently limitations in Unity Catalog (only managed tables and in preview, no external locations)

-------------------
Here use Terraform to create another storage account, 3 containers, SQL, EventHub and run generators to create and stream data.
Create external locations in Databricks.
-------------------

12. Ingesting - autoloader storage, SQL, Kafka
```python
# Autoloader for users
data_path = f"abfss://bronze@hmeuljyuevdo.dfs.core.windows.net/users/"
checkpoint_path = f"abfss://bronze@hmeuljyuevdo.dfs.core.windows.net/_checkpoint/users"

(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "json")
  .option("cloudFiles.schemaLocation", checkpoint_path)
  .load(data_path)
  .writeStream
  .option("checkpointLocation", checkpoint_path)
  .trigger(availableNow=True)
  .toTable("main.demobronze.users"))

# Autoloader for vipusers
data_path = f"abfss://bronze@hmeuljyuevdo.dfs.core.windows.net/vipusers/"
checkpoint_path = f"abfss://bronze@hmeuljyuevdo.dfs.core.windows.net/_checkpoint/vipusers"

(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "json")
  .option("cloudFiles.schemaLocation", checkpoint_path)
  .load(data_path)
  .writeStream
  .option("checkpointLocation", checkpoint_path)
  .trigger(availableNow=True)
  .toTable("main.demobronze.vipusers"))

# Autoloader for products
data_path = f"abfss://bronze@hmeuljyuevdo.dfs.core.windows.net/products/"
checkpoint_path = f"abfss://bronze@hmeuljyuevdo.dfs.core.windows.net/_checkpoint/products"

(spark.readStream
  .format("cloudFiles")
  .option("cloudFiles.format", "json")
  .option("cloudFiles.schemaLocation", checkpoint_path)
  .load(data_path)
  .writeStream
  .option("checkpointLocation", checkpoint_path)
  .trigger(availableNow=True)
  .toTable("main.demobronze.products"))

# Use UI to check tables in demobronze schema (also known as database) in main catalog.
# Note products history -> new data files are arriving and we can see transactions in table
```

```sql
-- Create SQL cell to import data from Azure SQL

-- Create table object on top of Azure SQL
CREATE TABLE IF NOT EXISTS jdbc_orders
USING org.apache.spark.sql.jdbc
OPTIONS (
   url "jdbc:sqlserver://{sqlservername}.database.windows.net:1433;database=orders",
   database "orders",
   dbtable "orders",
   user "tomas",
   password "{azuresql_password}"
 );

CREATE TABLE IF NOT EXISTS jdbc_items
USING org.apache.spark.sql.jdbc
OPTIONS (
   url "jdbc:sqlserver://{sqlservername}.database.windows.net:1433;database=orders",
   database "orders",
   dbtable "items",
   user "tomas",
   password "{azuresql_password}"
 );

-- COMMAND ----------

-- This can be queried now (direct query, basically on the fly translation)
%sql
SELECT * FROM jdbc_orders;

-- COMMAND ----------
%sql
SELECT * FROM jdbc_items;

-- COMMAND ----------
-- Let's copy it to Delta table
%sql
CREATE OR REPLACE TABLE main.demobronze.orders
AS SELECT * FROM jdbc_orders;

CREATE OR REPLACE TABLE main.demobronze.items
AS SELECT * FROM jdbc_items;
```

13.  More complex queries - silver/gold table JOINs
```sql
-- Goal: get count of unique products names per user based on orders and add flag to VIP users

-- Select users
SELECT users.id, users.user_name
FROM main.demobronze.users

-- Add is_vip flag by joining to vipusers
SELECT users.id,
       users.user_name,
       iff(isnull(vipusers.id), false, true) AS is_vip
FROM main.demobronze.users
LEFT JOIN main.demobronze.vipusers ON users.id = vipusers.id

-- Preparation - join users with orders
SELECT users.id,
       orders.orderId,
       orders.userId
FROM main.demobronze.users
LEFT JOIN main.demobronze.orders ON users.id = orders.userId

-- Preparation - join orders with items
SELECT users.id,
       orders.orderId,
       orders.userId,
       items.productId
FROM main.demobronze.users
LEFT JOIN main.demobronze.orders ON users.id = orders.userId
LEFT JOIN main.demobronze.items ON orders.orderId = items.orderId

-- Preparation - join items with products
SELECT users.id,
       products.name
FROM main.demobronze.users
LEFT JOIN main.demobronze.orders ON users.id = orders.userId
LEFT JOIN main.demobronze.items ON orders.orderId = items.orderId
LEFT JOIN main.demobronze.products ON items.productId = products.id

-- Continue by joining previous query with this one
SELECT users.id,
       users.user_name,
       products.name,
       iff(isnull(vipusers.id), false, true) AS is_vip
FROM main.demobronze.users
LEFT JOIN main.demobronze.vipusers ON users.id = vipusers.id
LEFT JOIN (
  SELECT users.id,
         products.name
  FROM main.demobronze.users
  LEFT JOIN main.demobronze.orders ON users.id = orders.userId
  LEFT JOIN main.demobronze.items ON orders.orderId = items.orderId
  LEFT JOIN main.demobronze.products ON items.productId = products.id
  ) AS products ON users.id = products.id

-- Almost there, just add dcount and group by
SELECT users.id,
       users.user_name,
       COUNT(DISTINCT products.name) AS num_unique_products,
       iff(isnull(vipusers.id), false, true) AS is_vip
FROM main.demobronze.users
LEFT JOIN main.demobronze.vipusers ON users.id = vipusers.id
LEFT JOIN (
  SELECT users.id,
         products.name
  FROM main.demobronze.users
  LEFT JOIN main.demobronze.orders ON users.id = orders.userId
  LEFT JOIN main.demobronze.items ON orders.orderId = items.orderId
  LEFT JOIN main.demobronze.products ON items.productId = products.id
  ) AS products ON users.id = products.id
GROUP BY users.id, users.user_name, vipusers.id

-- Final query to create table in gold
CREATE OR REPLACE TABLE main.demogold.user_products
AS
SELECT users.id,
       users.user_name,
       COUNT(DISTINCT products.name) AS num_unique_products,
       iff(isnull(vipusers.id), false, true) AS is_vip
FROM main.demobronze.users
LEFT JOIN main.demobronze.vipusers ON users.id = vipusers.id
LEFT JOIN (
  SELECT users.id,
         products.name
  FROM main.demobronze.users
  LEFT JOIN main.demobronze.orders ON users.id = orders.userId
  LEFT JOIN main.demobronze.items ON orders.orderId = items.orderId
  LEFT JOIN main.demobronze.products ON items.productId = products.id
  ) AS products ON users.id = products.id
GROUP BY users.id, users.user_name, vipusers.id

-- We can not query precalculated table and visualize
SELECT * FROM main.demogold.user_products

-- We can now create dashboard
```

14.  Streaming with DLT - Ingesting
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

15.  Streaming with DLT - Parsing
```sql
CREATE OR REFRESH STREAMING LIVE TABLE parsed_pageviews
AS SELECT timestamp,
  get_json_object(CAST(value AS string), '$.user_id') AS user_id,
  get_json_object(CAST(value AS string), '$.http_method') AS http_method,
  get_json_object(CAST(value AS string), '$.uri') AS uri,
  get_json_object(CAST(value AS string), '$.client_ip') AS client_ip,
  get_json_object(CAST(value AS string), '$.user_agent') AS user_agent, 
  get_json_object(CAST(value AS string), '$.latency') AS latency 
FROM STREAM(live.stream_pageviews)

CREATE OR REFRESH STREAMING LIVE TABLE parsed_stars
AS SELECT timestamp,
  get_json_object(CAST(value AS string), '$.user_id') AS user_id,
  get_json_object(CAST(value AS string), '$.stars') AS stars
FROM STREAM(live.stream_stars)
```

16.  Streaming with DLT - Processing
This is typical silver tier processing:
- Preprocessed table with pageviews that experienced high latency
- Correlate stars events from user that happen within 15 minutes of pageview -> users that gave stars after viewing our pages
  
```sql
CREATE OR REFRESH STREAMING LIVE TABLE high_latency
AS SELECT *
FROM STREAM(live.parsed_pageviews)
WHERE latency > 4000

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
  AND DATEDIFF(MINUTE, live.parsed_pageviews.timestamp,live.parsed_stars.timestamp) BETWEEN 0 AND 15 
```

16.  Streaming with DLT - Gold table
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

17. ML - data cleanup and preparation
18. ML - model training and deployment
19. Feature Store








