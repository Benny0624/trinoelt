# TRINO LOCAL DEPLOYMENT : benny-trino

## Start trino cluster
1. Generate self-signed certification

You can generate a self-signed certificate using the following command, DO NOT use it on your online environment.
```
## Create directory for certs
mkdir ./local/init/trino/certs/

keytool -genkeypair -alias trino -keyalg RSA -keystore ./local/init/trino/certs/keystore.jks \
-dname "CN=coordinator, OU=datalake, O=dataco, L=Sydney, ST=NSW, C=AU" \
-ext san=dns:coordinator,dns:coordinator.presto,dns:coordinator.presto.svc,dns:coordinator.presto.svc.cluster.local,dns:coordinator-headless,dns:coordinator-headless.presto,dns:coordinator-headless.presto.svc,dns:coordinator-headless.presto.svc.cluster.local,dns:localhost,dns:trino-proxy,ip:127.0.0.1,ip:192.168.64.5,ip:192.168.64.6 \
-storepass password

keytool -exportcert -file ./local/init/trino/certs/trino.cer -alias trino -keystore ./local/init/trino/certs/keystore.jks -storepass password

keytool -import -v -trustcacerts -alias trino_trust -file ./local/init/trino/certs/trino.cer -keystore ./local/init/trino/certs/truststore.jks -storepass password -keypass password -noprompt

keytool -keystore ./local/init/trino/certs/keystore.jks -exportcert -alias trino -storepass password| openssl x509 -inform der -text

keytool -importkeystore -srckeystore ./local/init/trino/certs/keystore.jks -destkeystore ./local/init/trino/certs/trino.p12 -srcstoretype jks -deststoretype pkcs12 -srcstorepass password -deststorepass password

openssl pkcs12 -in ./local/init/trino/certs/trino.p12 -out ./local/init/trino/certs/trino.pem -passin pass:password -passout pass:password

openssl x509 -in ./local/init/trino/certs/trino.cer -inform DER -out ./local/init/trino/certs/trino.crt
```

2. Make sure .env is well set
   - Refer to ./local/init/trino/.env.example
   - Create a service account in AWS (shopline-test) if needed
     - Path: Login AWS (shopline-test) -> IAM -> Users -> Create user
     - Auth: Make sure Trino service account has enough auth for every services (S3/AWS glue)
     - If you don't want to create account, you may use "sldatacenter-infra-flink-development" in replacement
   - Use service account key to set .env value (DO NOT USE PERSONAL ACCOUNT)

3. Run containers
```
make build profiles=trino
make start profiles=trino
```

4. Use trino-cli to test https
```
# Download trino-cli
curl -s -o trino https://repo1.maven.org/maven2/io/trino/trino-cli/443/trino-cli-443-executable.jar
chmod +x ./trino

# Add new user to password file
htpasswd -B -C 10 local/init/trino-elt/coordinator/password.db <user_name>

# Set password for newly created account
## password saved in password.db
## local acct is the same as password
## user group is set to : ./local/init/trino/coordinator/group.txt

# login trino
./trino --server https://localhost:8443 --truststore-path ./local/init/trino/certs/truststore.jks --truststore-password=password --user <user_name> --password

# test trino
trino> show catalogs;

 Catalog
----------
 system
(3 rows)

Query 20240516_032329_00000_zymbr, FINISHED, 1 node
Splits: 11 total, 11 done (100.00%)
11.70 [0 rows, 0B] [0 rows/s, 0B/s]
```

## Set new data source
```
# set the coordinator catalog folders (data-center-infra/local/init/trino/coordinator/catalog)
# set the worker catalog folders (data-center-infra/local/init/trino/worker*/catalog)
# set access_rule.json (./local/init/trino/coordinator/access_rules.json)
    {
        "group": "admin",
        "catalog": "(bigquery|hive|iceberg|tpcds|tpch|mongodb|tidb|<ADD NEW CATALOG HERE>)",
        "allow": "all"
    }
```

### Example
#### BigQuery
```
# bigquery.properties
connector.name=bigquery
bigquery.project-id=shopline-test
bigquery.credentials-file=/etc/trino/.credentials/gcp_service_account.json
```
```
trino> show catalogs;
 Catalog
----------
 bigquery
 system
```

#### Iceberg
```
# iceberg.properties
connector.name=iceberg
iceberg.catalog.type=glue
iceberg.file-format=PARQUET
hive.metastore.glue.region=ap-southeast-1
hive.metastore.glue.default-warehouse-dir=s3://sldatacenter-trino-development
hive.metastore.glue.aws-access-key=
hive.metastore.glue.aws-secret-key=
hive.s3.aws-access-key=
hive.s3.aws-secret-key=
```
```
trino> show catalogs;
 Catalog
----------
 iceberg
 system

```

#### Hive
```
# hive.properties
connector.name=hive

hive.recursive-directories=true

hive.metastore=glue
hive.metastore.glue.region=ap-southeast-1
hive.metastore.glue.default-warehouse-dir=s3://sldatacenter-trino-development
hive.metastore.glue.aws-access-key=
hive.metastore.glue.aws-secret-key=

fs.native-gcs.enabled=true
gcs.project-id=shopline-test
gcs.json-key-file-path=/etc/trino/.credentials/gcp_service_account.json
```
```
trino> show catalogs;
 Catalog
----------
 hive
 system
```

#### Tidb
```
# tidb.properties
connector.name=mysql
connection-url=jdbc:mysql://tidb:4000
connection-user=root
connection-password=
```
```
trino> show catalogs;
 Catalog
----------
 tidb
 system
```

##### IMPORTANT
```
# if you query local tidb encouter below,
# please set tidb_enable_noop_functions to true like below in local tidb
Query 20250115_082700_00029_z9efk failed: function READ ONLY has only noop implementation in tidb now, use tidb_enable_noop_functions to enable these functions

SET GLOBAL tidb_enable_noop_functions = 1;
```

## Trino Query
### Show Schema
```
trino> SHOW SCHEMAS FROM iceberg;
               Schema
------------------------------------
 datalakehouse_bronze_development
 datalakehouse_elt_raw_development
 datalakehouse_elt_temp_development
 datalakehouse_silver_development
 information_schema
```
### Show Table
```
trino> SHOW TABLES FROM iceberg.datalakehouse_bronze_development;
    Table
--------------
 bill
 bill_payment
 canal_json
 credit_memo
 invoice
 invoice2
 payment
 stan
...
```
### Show Table Columns
```
trino> DESCRIBE iceberg.datalakehouse_bronze_development.payment;
   Column    |  Type   | Extra | Comment
-------------+---------+-------+---------
 date        | varchar |       |
 amount      | double  |       |
 invoice_num | bigint  |       |
 id          | bigint  |       |
 table       | varchar |       |
```
### QUERY
#### create test table and insert fake data
```
CREATE TABLE iceberg.datalakehouse_bronze_development.benny (
    id BIGINT,
    name VARCHAR,
    age INTEGER,
    city VARCHAR,
    join_date DATE
);

INSERT INTO iceberg.datalakehouse_bronze_development.benny (id, name, age, city, join_date)
SELECT *
FROM(
SELECT
    CAST(rand() * 100000 AS BIGINT) AS id,
    element_at(array['Alice', 'Bob', 'Charlie', 'David', 'Eve'], CAST(rand() * 5 + 1 AS INTEGER)) AS name,
    CAST(rand() * 60 + 20 AS INTEGER) AS age,
    element_at(array['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'], CAST(rand() * 5 + 1 AS INTEGER)) AS city,
    DATE '2023-01-01' + INTERVAL '1' day * CAST(rand() * 365 AS INTEGER) AS join_date
FROM UNNEST(SEQUENCE(1, 10000)) AS t(x)
UNION ALL
SELECT
    CAST(rand() * 100000 AS BIGINT) AS id,
    element_at(array['Alice', 'Bob', 'Charlie', 'David', 'Eve'], CAST(rand() * 5 + 1 AS INTEGER)) AS name,
    CAST(rand() * 60 + 20 AS INTEGER) AS age,
    element_at(array['New York', 'Los Angeles', 'Chicago', 'Houston', 'Phoenix'], CAST(rand() * 5 + 1 AS INTEGER)) AS city,
    DATE '2023-01-01' + INTERVAL '1' day * CAST(rand() * 365 AS INTEGER) AS join_date
FROM UNNEST(SEQUENCE(1, 10000)) AS t(x)
);
```
#### select query-partition-filter-required table test if it works
```
SHOW TABLES FROM iceberg.datalakehouse_elt_raw_development;
SHOW TABLES FROM iceberg.datalakehouse_silver_development;
SHOW CREATE TABLE iceberg.datalakehouse_elt_raw_development.mongo_core_shopline_orders_related;
SHOW CREATE TABLE iceberg.datalakehouse_silver_development.mongo_archived_orders_shopline_archived_order_items;

SELECT
    *
FROM
    iceberg.datalakehouse_elt_raw_development.mongo_core_shopline_orders_related;
SELECT
    *
FROM
    iceberg.datalakehouse_silver_development.mongo_archived_orders_shopline_archived_order_items
WHERE merchant_id IS NOT NULL;
```
