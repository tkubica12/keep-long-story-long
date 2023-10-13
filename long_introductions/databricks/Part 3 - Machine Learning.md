# Part 3 - Machine Learning

### 1. Load data
```python
# Download data
import requests
import os

path = "abfss://bronze@klsldatalake554.dfs.core.windows.net/lending_club.csv"

# Load CSV file
df = spark.read.format("csv") \
  .option("inferSchema", True) \
  .option("header", True) \
  .option("sep", ",") \
  .option("multiline", True) \
  .load(path)

# This public data is anonymous, but for our purposes let's pretend we have personalized data
# Add user_id column with random guid
from pyspark.sql.functions import uuid
df = df.withColumn("user_id", uuid())
display(df)

# Save to table
df.write.format("delta").mode("overwrite").saveAsTable("main.default.lending_club_raw")
```

### 2. Prepare labels
```python
# Load raw data from table into DataFrame
df = spark.read.format("delta").table("main.default.lending_club_raw")

# Our target (label) is loan status, this is what we want to predict
# There are just two options (it is binary), so let's convert it to 0 or 1
df.select("loan_status").distinct().display()

from pyspark.sql.functions import when

df = df.withColumn("loan_status", when(df["loan_status"] == "Fully Paid", 1).otherwise(0))

df.select("loan_status").distinct().display()

# Save to table
df.write.format("delta").mode("overwrite").saveAsTable("main.default.lending_club_labels")
```

### 3. Clean data, prepare features
```python
# Load labeled data from table into DataFrame
df = spark.read.format("delta").table("main.default.lending_club_labels")
display(df)

# We will drop features we do not need. Grade is part of subgrade and issue_d is not needed
df = df.drop("grade", "issue_d")
display(df)

# Do we have any missing data in columns
# import pyspark.sql.functions as F
# null_counts = df.select([F.count(F.when(F.col(c).isNull(), c)).alias(c) for c in df.columns])
# display(null_counts)

missing_counts = [(column, df.filter(df[column].isNull()).count()) for column in df.columns]
missing_counts_sorted = sorted(missing_counts, key=lambda x: x[1], reverse=True)

for column, count in missing_counts_sorted:
    if count > 0:
        print(column, ":", count) 

# Low number of rows with missing values can be just deleted,
# but we need to focus on high numbers of missing values: mort_acc, emp_title, emp_length

# mort_acc -> fill with mean
from pyspark.sql.functions import mean

mean_mort_acc = df.select(mean("mort_acc")).collect()[0][0]
df = df.fillna(mean_mort_acc, subset=["mort_acc"])

# emp_title -> fill with category Unknown
df = df.fillna("Unknown", subset=["emp_title"])

# emp_length -> fill with most common categorical value
emp_length_mode = df.groupBy('emp_length').count().orderBy('count', ascending=False).first()[0]
df = df.fillna(emp_length_mode, subset=['emp_title'])

# Other columns missing values are in low numbers and we safely drop those rows
df = df.dropna()

# We might want to limit some categorical values by introducing Other
# emp_title (job title) and title (title of loan) consist of 10000 different titles
df.groupBy("emp_title").count().orderBy("count", ascending=False).display()
df.groupBy("title").count().orderBy("count", ascending=False).display()

# Keep top 30 and rest replace with Other
top30_emp_title = [x[0] for x in df.groupBy("emp_title").count().orderBy("count", ascending=False).take(30)]
df = df.withColumn("emp_title", when(df["emp_title"].isin(top30_emp_title), df["emp_title"]).otherwise("Other"))

top30_title = [x[0] for x in df.groupBy("title").count().orderBy("count", ascending=False).take(30)]
df = df.withColumn("title", when(df["title"].isin(top30_title), df["title"]).otherwise("Other"))

# Feature term can be converted from string to number
from pyspark.sql.functions import regexp_extract
df = df.withColumn("term", regexp_extract("term", "\\d+", 0).cast("integer")).display()

# Check categories of home_ownership
display(df.groupBy("home_ownership").count())

# Let's consolidate categories ANY, OTHER and NONE into single category OTHER
from pyspark.sql.functions import when

df = df.withColumn("home_ownership", when(df["home_ownership"].isin({"NONE", "ANY"}), "OTHER").otherwise(df["home_ownership"]))

# Address is very specific, would be very high cardinality categorical feature
# Let's parse zip code out of and work with that to lower cardinality
df = df.withColumn("zip_code", df["address"].substr(-5, 5))
df = df.drop("address")

# earliest_cr_line is too granular, for us year is enough, let's parse it as number
df = df.withColumn("earliest_cr_year", df["earliest_cr_line"].substr(-4, 4).cast("integer"))
df = df.drop("earliest_cr_line")

# That's it, we are ready to save our cleaned data
display(df)
df.write.format("delta").mode("overwrite").saveAsTable("main.default.lending_club_cleaned")
```

### 4. Train
```python
# Load cleaned data from table into DataFrame
df = spark.read.format("delta").table("main.default.lending_club_cleaned")

# Split data
train_df, test_df = df.randomSplit([0.8, 0.2])

print(f"Train count: {train_df.count()}")
print(f"Test count: {test_df.count()}")

from pyspark.ml.feature import OneHotEncoder, StringIndexer, VectorAssembler

# Get columns of type string
categorical_cols = [field for (field, dataType) in train_df.dtypes if dataType == "string"]

# Create name for categorical columns - one for index, one for OHE
index_output_cols = [x + "Index" for x in categorical_cols]
ohe_output_cols = [x + "OHE" for x in categorical_cols]

# Assign index to each category
string_indexer = StringIndexer(inputCols=categorical_cols, outputCols=index_output_cols, handleInvalid="skip")

# Convert category index to binary vector (dummy variables)
ohe_encoder = OneHotEncoder(inputCols=index_output_cols, outputCols=ohe_output_cols)

# Create vector of features (numerical + categorical)
numeric_cols = [field for (field, dataType) in train_df.dtypes if (dataType in ["int", "double"])]
assembler_inputs = ohe_output_cols + numeric_cols
vec_assembler = VectorAssembler(inputCols=assembler_inputs, outputCol="features")

# Define model
from pyspark.ml.classification import LogisticRegression
 
lr = LogisticRegression(featuresCol="features", labelCol="loan_status")

# Define pipeline
from pyspark.ml import Pipeline
 
pipeline = Pipeline(stages=[string_indexer, ohe_encoder, vec_assembler, lr])
model = pipeline.fit(train_df)
 
# Apply the pipeline model to the test dataset.
pred_df = model.transform(test_df)

from pyspark.ml.evaluation import BinaryClassificationEvaluator, MulticlassClassificationEvaluator
 
multiclass_evaluator = MulticlassClassificationEvaluator(labelCol="loan_status", predictionCol="prediction", metricName="f1")
f1_score = multiclass_evaluator.evaluate(pred_df)
print(f"F1 Score: {f1_score}")

multiclass_evaluator.setMetricName("accuracy")
accuracy = multiclass_evaluator.evaluate(pred_df)
print(f"Accuracy: {accuracy}")
```



### 5. ML - train test split
2. ML - model training and deployment
3. Feature Store