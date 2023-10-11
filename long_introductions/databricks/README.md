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

14.  Streaming with DLT
15. ML - data cleanup and preparation
16. ML - model training and deployment
17. Feature Store








