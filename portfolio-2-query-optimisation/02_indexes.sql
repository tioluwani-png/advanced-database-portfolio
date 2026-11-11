-- =====================================================================
-- Portfolio 2 — 02_indexes.sql
-- The optimisation: six indexes, each designed for a specific Relaks
-- query in 03_benchmark.sql. (03_benchmark.sql drops and re-creates these
-- itself to measure before/after; this file documents them on their own.)
-- =====================================================================
SET search_path TO relaks;

-- Q1  WhatsApp/phone order lookup: customers message from their phone number.
CREATE INDEX IF NOT EXISTS ix_customer_phone
    ON customer (phone);

-- Q1  A customer's orders, newest first. Composite index: equality column
--     first, then the sort column, so PostgreSQL reads rows already sorted.
--     (Replaces Portfolio 1's single-column ix_order_customer.)
CREATE INDEX IF NOT EXISTS ix_order_customer_date
    ON customer_order (customer_id, ordered_at DESC);

-- Q2 / Q5b  Date-range reports (Black Friday weekend, a single day).
CREATE INDEX IF NOT EXISTS ix_order_date
    ON customer_order (ordered_at);

-- Q3  Dispatch queue: only ~3% of orders are 'paid' and waiting for a rider.
--     PARTIAL index: it stores only those rows, so it stays tiny.
CREATE INDEX IF NOT EXISTS ix_order_paid_queue
    ON customer_order (ordered_at)
    WHERE order_status = 'paid';

-- Q4  Overdue Reading Club books: only unreturned loans matter.
--     PARTIAL index on the small "still out" subset.
CREATE INDEX IF NOT EXISTS ix_loan_overdue
    ON rental_loan (due_on)
    WHERE returned_on IS NULL;

-- Q6  Product revenue report. COVERING index (INCLUDE) so the totals can
--     be computed from the index alone (index-only scan), if the planner
--     judges it cheaper than reading the table.
CREATE INDEX IF NOT EXISTS ix_item_product_cover
    ON order_item (product_id) INCLUDE (quantity, unit_price_at_purchase);

ANALYZE;
