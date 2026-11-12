-- =====================================================================
-- Portfolio 3 — 04_select_for_update_fix.sql
-- THE FIX: pessimistic row locking with SELECT ... FOR UPDATE.
--
-- Same two tabs as 03, plus a THIRD tab (Tab C) to watch the locks.
-- FOR UPDATE locks the Lavender row when the checkout reads it. A second
-- checkout that tries to read it FOR UPDATE must WAIT until the first one
-- commits or rolls back, and then it sees the up-to-date stock.
-- =====================================================================


-- ===== STEP 0 (any tab): reset the demo =====
CALL relaks.p3_reset();
SELECT * FROM relaks.lavender_status;          -- 1 copy left, no sale yet


-- ===== STEP 1 (Tab A, Adaeze): read the stock AND lock the row =====
BEGIN;
SELECT stock_qty FROM relaks.product WHERE sku = 'BOOK-LAV' FOR UPDATE;   -- 1, row now locked


-- ===== STEP 2 (Tab B, Tunde): try to do the same =====
BEGIN;
SELECT stock_qty FROM relaks.product WHERE sku = 'BOOK-LAV' FOR UPDATE;   -- WAITS (spinner)


-- ===== STEP 3 (Tab C): watch the lock =====
SELECT * FROM relaks.lock_monitor;
-- Tunde's session shows wait_event_type = Lock, wait_event = transactionid,
-- and blocked_by_pid = Adaeze's session.


-- ===== STEP 4 (Tab A, Adaeze): pay and commit =====
UPDATE relaks.product SET stock_qty = stock_qty - 1 WHERE sku = 'BOOK-LAV';
SELECT relaks.p3_create_order(1, 'BOOK-LAV', 'P3-LOCK-ADAEZE');
COMMIT;
-- The moment this commits, Tab B's waiting SELECT finishes and returns 0.


-- ===== STEP 5 (Tab B, Tunde): the app sees 0 copies, shows "Sold out" =====
ROLLBACK;


-- ===== STEP 6 (any tab): result =====
SELECT * FROM relaks.lavender_status;          -- 0 left, 1 paid order: correct


-- ---------------------------------------------------------------------
-- Alternative fix (no explicit lock): make the check and the write one
-- atomic statement. It only succeeds if a copy is still there:
--
--   UPDATE relaks.product SET stock_qty = stock_qty - 1
--   WHERE sku = 'BOOK-LAV' AND stock_qty >= 1
--   RETURNING stock_qty;      -- 0 rows returned  =>  sold out
-- ---------------------------------------------------------------------
