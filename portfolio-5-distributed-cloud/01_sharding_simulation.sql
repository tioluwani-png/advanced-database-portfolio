-- =====================================================================
-- Portfolio 5 — 01_sharding_simulation.sql
-- Sharding, simulated with PostgreSQL declarative partitioning.
--
-- A sharded database splits one big table across several servers by a
-- SHARD KEY. Each partition below plays the part of one shard, so the same
-- questions can be tested on one laptop: is the data spread evenly, which
-- queries reach only one shard, and which have to ask every shard?
-- (Extensions such as Citus put each partition on a different server.)
--
-- Uses the 300,000 orders generated in Portfolio 2. Run each STEP on its
-- own in pgAdmin (highlight it, F5). Read-only for relaks.* tables: the
-- copies are made in a separate schema "dist", which STEP 7 removes.
-- =====================================================================


-- ===== STEP 1: shard by HASH of customer_id (4 shards) =====
CREATE SCHEMA IF NOT EXISTS dist;
DROP TABLE IF EXISTS dist.orders_by_customer CASCADE;

CREATE TABLE dist.orders_by_customer (
    order_id      INT          NOT NULL,
    customer_id   INT          NOT NULL,
    sales_channel VARCHAR(15)  NOT NULL,
    order_status  VARCHAR(15)  NOT NULL,
    delivery_fee  NUMERIC(10,2) NOT NULL,
    ordered_at    TIMESTAMPTZ  NOT NULL,
    PRIMARY KEY (customer_id, order_id)          -- must include the shard key (see STEP 6)
) PARTITION BY HASH (customer_id);

CREATE TABLE dist.shard_0 PARTITION OF dist.orders_by_customer FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE dist.shard_1 PARTITION OF dist.orders_by_customer FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE dist.shard_2 PARTITION OF dist.orders_by_customer FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE dist.shard_3 PARTITION OF dist.orders_by_customer FOR VALUES WITH (MODULUS 4, REMAINDER 3);

INSERT INTO dist.orders_by_customer
SELECT order_id, customer_id, sales_channel, order_status, delivery_fee, ordered_at
FROM   relaks.customer_order;

CREATE INDEX ON dist.orders_by_customer (customer_id, ordered_at DESC);
ANALYZE dist.orders_by_customer;


-- ===== STEP 2: is the data spread evenly across the shards? =====
SELECT tableoid::regclass                                   AS shard,
       count(*)                                             AS orders,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1)   AS pct_of_all,
       count(DISTINCT customer_id)                          AS customers
FROM   dist.orders_by_customer
GROUP  BY 1
ORDER  BY 1;
-- Expect about 25% each: hashing spreads 50,000 customers evenly.


-- ===== STEP 3: a TARGETED query (contains the shard key) =====
-- "My orders" for one customer: the router knows exactly which shard holds
-- customer 1, so only ONE shard does any work.
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF)
SELECT order_id, ordered_at, order_status
FROM   dist.orders_by_customer
WHERE  customer_id = 1
ORDER  BY ordered_at DESC;
-- Expect: a scan on a single dist.shard_N, the other three are pruned.


-- ===== STEP 4: a SCATTER-GATHER query (no shard key) =====
-- "Orders per channel this month" for the finance report: the date says
-- nothing about which shard to use, so EVERY shard must be asked and the
-- results merged (Append). Fine for a nightly report, costly if frequent.
SET max_parallel_workers_per_gather = 0;     -- keeps the plan short and readable
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY OFF)
SELECT sales_channel, count(*)
FROM   dist.orders_by_customer
WHERE  ordered_at >= '2026-10-01'
GROUP  BY sales_channel;
-- Expect: Append over dist.shard_0, shard_1, shard_2 and shard_3.


-- ===== STEP 5: a BAD shard key — RANGE by month (hot shard) =====
-- Sharding by date looks natural, but every NEW order has the newest date,
-- so all of today's writes land on ONE shard while the others sit idle.
DROP TABLE IF EXISTS dist.orders_by_month CASCADE;
CREATE TABLE dist.orders_by_month (LIKE dist.orders_by_customer)
PARTITION BY RANGE (ordered_at);

DO $$
DECLARE m DATE := DATE '2025-11-01';
BEGIN
    WHILE m <= DATE '2026-11-01' LOOP
        EXECUTE format(
          'CREATE TABLE dist.month_%s PARTITION OF dist.orders_by_month FOR VALUES FROM (%L) TO (%L)',
          to_char(m, 'YYYY_MM'), m, (m + INTERVAL '1 month')::date);
        m := (m + INTERVAL '1 month')::date;
    END LOOP;
END $$;

INSERT INTO dist.orders_by_month SELECT * FROM dist.orders_by_customer;
ANALYZE dist.orders_by_month;

-- Where did the LAST 7 DAYS of orders (the "hot" writes) go, under each key?
SELECT 'hash(customer_id)' AS shard_key, tableoid::regclass AS shard, count(*) AS orders_last_7_days
FROM   dist.orders_by_customer
WHERE  ordered_at >= (SELECT max(ordered_at) FROM relaks.customer_order) - INTERVAL '7 days'
GROUP  BY 2
UNION ALL
SELECT 'range(ordered_at)', tableoid::regclass, count(*)
FROM   dist.orders_by_month
WHERE  ordered_at >= (SELECT max(ordered_at) FROM relaks.customer_order) - INTERVAL '7 days'
GROUP  BY 2
ORDER  BY 1, 2;
-- Expect: hash spreads the week's orders over 4 shards; range puts them
-- on 1–2 monthly shards (a hotspot).


-- ===== STEP 6: global uniqueness needs the shard key =====
-- Each shard can only check uniqueness on its own data, so a UNIQUE rule
-- that does not include the shard key cannot be enforced across shards.
ALTER TABLE dist.orders_by_customer ADD CONSTRAINT order_id_unique UNIQUE (order_id);
-- Expect: ERROR: unique constraint on partitioned table must include all
-- partitioning columns. (MongoDB has the same rule for sharded collections.)


-- ===== STEP 7: tidy up =====
DROP SCHEMA dist CASCADE;
