-- =====================================================================
-- Portfolio 3 — 06_deadlock.sql
-- Deadlock detection: PostgreSQL's last-resort concurrency control.
--
-- Two staff members restock two editions at the same time, but in
-- opposite order. Each ends up waiting for a row the other has locked.
-- Neither can ever finish, so PostgreSQL detects the cycle (after
-- deadlock_timeout, 1 second by default) and aborts one of them.
-- =====================================================================


-- ===== STEP 0 (Tab A): reset, run ON ITS OWN =====
-- (In pgAdmin, if this runs in the same go as BEGIN, the reset's updates
--  join the transaction and lock Teal too, so Tab B would just wait.)
CALL relaks.p3_reset();


-- ===== STEP 1 (Tab A): restock Pink first =====
BEGIN;
UPDATE relaks.product SET stock_qty = stock_qty + 10 WHERE sku = 'BOOK-PINK';   -- locks Pink


-- ===== STEP 2 (Tab B): restock Teal first =====
BEGIN;
UPDATE relaks.product SET stock_qty = stock_qty + 10 WHERE sku = 'BOOK-TEAL';   -- locks Teal


-- ===== STEP 3 (Tab A): now Teal =====
UPDATE relaks.product SET stock_qty = stock_qty + 10 WHERE sku = 'BOOK-TEAL';   -- WAITS for B


-- ===== STEP 4 (Tab B): now Pink -> deadlock =====
UPDATE relaks.product SET stock_qty = stock_qty + 10 WHERE sku = 'BOOK-PINK';
-- ERROR: deadlock detected
-- DETAIL: Process X waits for ShareLock on transaction ...; blocked by process Y.
--         Process Y waits for ShareLock on transaction ...; blocked by process X.
-- PostgreSQL aborts Tab B's transaction, which releases Teal, so Tab A's
-- waiting UPDATE immediately succeeds.
ROLLBACK;


-- ===== STEP 5 (Tab A): finish =====
COMMIT;
-- Prevention: always lock rows in the same order (e.g. by product_id),
-- so two transactions can never wait for each other in a circle.
