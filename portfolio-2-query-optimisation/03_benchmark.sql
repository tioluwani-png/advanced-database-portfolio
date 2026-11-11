-- =====================================================================
-- Portfolio 2 — 03_benchmark.sql
-- Measures 7 real Relaks queries BEFORE and AFTER indexing, and saves
-- every execution plan (EXPLAIN ANALYZE) so they can be compared.
--
-- 1. Drops the optimisation indexes  ->  "before" phase
-- 2. Times each query (1 warm-up + average of 5 runs) and saves its plan
-- 3. Creates the indexes from 02_indexes.sql  ->  "after" phase
-- 4. Times and plans each query again
-- 5. Prints a before/after summary table
--
-- Results are kept in the "perf" schema. View plans with 04_show_plans.sql.
-- Took about 30 seconds on my laptop.
-- =====================================================================
SET search_path TO relaks;

DROP SCHEMA IF EXISTS perf CASCADE;
CREATE SCHEMA perf;

CREATE TABLE perf.query (
    qid          TEXT PRIMARY KEY,
    description  TEXT NOT NULL,
    sql_text     TEXT NOT NULL
);
CREATE TABLE perf.result (
    qid     TEXT REFERENCES perf.query,
    phase   TEXT CHECK (phase IN ('before','after')),
    avg_ms  NUMERIC(10,2),
    PRIMARY KEY (qid, phase)
);
CREATE TABLE perf.plan (
    qid        TEXT REFERENCES perf.query,
    phase      TEXT,
    line_no    INT,
    plan_line  TEXT,
    PRIMARY KEY (qid, phase, line_no)
);

-- ---------------------------------------------------------------------
-- The 7 business queries
-- ---------------------------------------------------------------------
INSERT INTO perf.query VALUES
('Q1', 'WhatsApp lookup: a customer''s orders by phone number, newest first',
 $q$SELECT o.order_id, o.ordered_at, o.order_status
    FROM relaks.customer c
    JOIN relaks.customer_order o ON o.customer_id = c.customer_id
    WHERE c.phone = '08000031337'
    ORDER BY o.ordered_at DESC$q$),

('Q2', 'Black Friday weekend 2025: revenue by sales channel',
 $q$SELECT o.sales_channel, COUNT(DISTINCT o.order_id) AS orders,
           SUM(oi.quantity * oi.unit_price_at_purchase) AS revenue
    FROM relaks.customer_order o
    JOIN relaks.order_item oi ON oi.order_id = o.order_id
    WHERE o.ordered_at >= '2025-11-28' AND o.ordered_at < '2025-12-01'
    GROUP BY o.sales_channel$q$),

('Q3', 'Dispatch queue: 50 oldest paid orders waiting for a rider',
 $q$SELECT order_id, customer_id, ordered_at
    FROM relaks.customer_order
    WHERE order_status = 'paid'
    ORDER BY ordered_at
    LIMIT 50$q$),

('Q4', 'Reading Club: overdue books not yet returned',
 $q$SELECT l.loan_id, s.customer_id, l.rental_book_id, l.due_on
    FROM relaks.rental_loan l
    JOIN relaks.rental_subscription s ON s.subscription_id = l.subscription_id
    WHERE l.returned_on IS NULL AND l.due_on < DATE '2026-11-10'
    ORDER BY l.due_on$q$),

('Q5a', 'Orders on one day, written with a function on the column (non-sargable)',
 $q$SELECT order_id, sales_channel, order_status
    FROM relaks.customer_order
    WHERE ordered_at::date = DATE '2026-06-15'$q$),

('Q5b', 'Same question rewritten as a range (sargable)',
 $q$SELECT order_id, sales_channel, order_status
    FROM relaks.customer_order
    WHERE ordered_at >= '2026-06-15' AND ordered_at < '2026-06-16'$q$),

('Q6', 'All-time revenue per product (reads most of order_item)',
 $q$SELECT p.product_name, SUM(oi.quantity * oi.unit_price_at_purchase) AS revenue
    FROM relaks.order_item oi
    JOIN relaks.product p ON p.product_id = oi.product_id
    GROUP BY p.product_name
    ORDER BY revenue DESC$q$);

-- ---------------------------------------------------------------------
-- Helper: run every query, store average time and the EXPLAIN ANALYZE plan
-- ---------------------------------------------------------------------
CREATE PROCEDURE perf.run_phase(p_phase TEXT, p_runs INT DEFAULT 5)
LANGUAGE plpgsql AS $$
DECLARE
    q      RECORD;
    t0     TIMESTAMPTZ;
    total  NUMERIC;
    ln     INT;
    line   TEXT;
BEGIN
    FOR q IN SELECT * FROM perf.query ORDER BY qid LOOP
        EXECUTE q.sql_text;                              -- warm-up (fills cache)
        total := 0;
        FOR i IN 1..p_runs LOOP
            t0 := clock_timestamp();
            EXECUTE q.sql_text;
            total := total + EXTRACT(EPOCH FROM clock_timestamp() - t0) * 1000;
        END LOOP;
        INSERT INTO perf.result VALUES (q.qid, p_phase, total / p_runs);

        ln := 0;
        FOR line IN EXECUTE 'EXPLAIN (ANALYZE, BUFFERS) ' || q.sql_text LOOP
            ln := ln + 1;
            INSERT INTO perf.plan VALUES (q.qid, p_phase, ln, line);
        END LOOP;
    END LOOP;
END $$;

-- ---------------------------------------------------------------------
-- PHASE 1: BEFORE (no optimisation indexes)
-- ---------------------------------------------------------------------
DROP INDEX IF EXISTS relaks.ix_customer_phone;
DROP INDEX IF EXISTS relaks.ix_order_customer;          -- Portfolio 1 FK index
DROP INDEX IF EXISTS relaks.ix_order_customer_date;
DROP INDEX IF EXISTS relaks.ix_order_date;
DROP INDEX IF EXISTS relaks.ix_order_paid_queue;
DROP INDEX IF EXISTS relaks.ix_loan_overdue;
DROP INDEX IF EXISTS relaks.ix_item_product_cover;
ANALYZE relaks.customer, relaks.customer_order, relaks.order_item, relaks.rental_loan;

CALL perf.run_phase('before');

-- ---------------------------------------------------------------------
-- PHASE 2: AFTER (same indexes as 02_indexes.sql)
-- ---------------------------------------------------------------------
CREATE INDEX ix_customer_phone       ON relaks.customer (phone);
CREATE INDEX ix_order_customer_date  ON relaks.customer_order (customer_id, ordered_at DESC);
CREATE INDEX ix_order_date           ON relaks.customer_order (ordered_at);
CREATE INDEX ix_order_paid_queue     ON relaks.customer_order (ordered_at) WHERE order_status = 'paid';
CREATE INDEX ix_loan_overdue         ON relaks.rental_loan (due_on) WHERE returned_on IS NULL;
CREATE INDEX ix_item_product_cover   ON relaks.order_item (product_id) INCLUDE (quantity, unit_price_at_purchase);
ANALYZE relaks.customer, relaks.customer_order, relaks.order_item, relaks.rental_loan;

CALL perf.run_phase('after');

-- ---------------------------------------------------------------------
-- SUMMARY: before vs after
-- ---------------------------------------------------------------------
SELECT q.qid,
       q.description,
       b.avg_ms                                   AS before_ms,
       a.avg_ms                                   AS after_ms,
       ROUND(b.avg_ms / NULLIF(a.avg_ms, 0), 1)   AS times_faster
FROM perf.query q
JOIN perf.result b ON b.qid = q.qid AND b.phase = 'before'
JOIN perf.result a ON a.qid = q.qid AND a.phase = 'after'
ORDER BY q.qid;
