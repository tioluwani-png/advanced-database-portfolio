-- =====================================================================
-- Portfolio 3 — 03_lost_update_problem.sql
-- THE CONCURRENCY PROBLEM: two customers buy the last Lavender copy.
--
-- Needs TWO Query Tool tabs on the relaks database:
--   Tab A = Adaeze's checkout      Tab B = Tunde's checkout
-- Run each STEP in the tab named, in order (highlight the step, F5).
--
-- The checkout reads the stock, decides in the application that there is
-- enough, then writes back the new stock it calculated. Under PostgreSQL's
-- default READ COMMITTED isolation nothing stops both checkouts from reading
-- "1" before either one writes, so both sell the same copy: a LOST UPDATE.
-- =====================================================================


-- ===== STEP 0 (either tab): reset the demo =====
CALL relaks.p3_reset();
SELECT * FROM relaks.lavender_status;          -- 1 copy left, no sale yet


-- ===== STEP 1 (Tab A, Adaeze): open checkout and read the stock =====
BEGIN;
SELECT stock_qty FROM relaks.product WHERE sku = 'BOOK-LAV';      -- sees 1  -> "in stock"


-- ===== STEP 2 (Tab B, Tunde): open checkout and read the stock =====
BEGIN;
SELECT stock_qty FROM relaks.product WHERE sku = 'BOOK-LAV';      -- ALSO sees 1 -> "in stock"


-- ===== STEP 3 (Tab A, Adaeze): pay; app writes the stock it calculated (1 - 1 = 0) =====
UPDATE relaks.product SET stock_qty = 0 WHERE sku = 'BOOK-LAV';
SELECT relaks.p3_create_order(1, 'BOOK-LAV', 'P3-LOST-ADAEZE');
COMMIT;


-- ===== STEP 4 (Tab B, Tunde): pay; his app ALSO calculated 1 - 1 = 0 =====
UPDATE relaks.product SET stock_qty = 0 WHERE sku = 'BOOK-LAV';
SELECT relaks.p3_create_order(2, 'BOOK-LAV', 'P3-LOST-TUNDE');
COMMIT;                                                            -- no error at all


-- ===== STEP 5 (either tab): the damage =====
SELECT * FROM relaks.lavender_status;          -- 0 left, 2 paid orders: OVERSOLD
