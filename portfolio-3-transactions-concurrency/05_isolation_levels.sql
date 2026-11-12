-- =====================================================================
-- Portfolio 3 — 05_isolation_levels.sql
-- READ COMMITTED vs REPEATABLE READ during a mid-sale price change.
--
-- Two tabs. Tab A = a finance report that reads the Pink Edition price
-- twice in one transaction. Tab B = the admin who changes the price
-- (Black Friday: ₦10,000 -> ₦8,000) while the report is running.
--
-- Tab A saves each reading into a temporary table (only visible to its
-- own session), so one result grid shows both readings side by side.
-- =====================================================================


-- ############ PART 1: READ COMMITTED (PostgreSQL's default) ############

-- ===== STEP 0 (Tab A): reset and prepare, run ON ITS OWN =====
-- (In pgAdmin, if this runs in the same go as BEGIN, the reset's UPDATE
--  joins the report's transaction and locks the Pink row, so Tab B's
--  price change just waits. That happened on my first attempt.)
CALL relaks.p3_reset();                                   -- Pink back to ₦10,000
CREATE TEMP TABLE IF NOT EXISTS readings (
    isolation_level TEXT,
    reading         TEXT,
    unit_price      NUMERIC,
    read_at         TIME DEFAULT clock_timestamp()::time
);
TRUNCATE readings;


-- ===== STEP 1 (Tab A): start the report =====
BEGIN ISOLATION LEVEL READ COMMITTED;
INSERT INTO readings (isolation_level, reading, unit_price)
SELECT 'READ COMMITTED', 'read 1', unit_price FROM relaks.product WHERE sku = 'BOOK-PINK';
SELECT * FROM readings;                                   -- read 1 = 10000


-- ===== STEP 2 (Tab B): admin changes the price (auto-commits) =====
UPDATE relaks.product SET unit_price = 8000 WHERE sku = 'BOOK-PINK';


-- ===== STEP 3 (Tab A): read again INSIDE THE SAME transaction =====
INSERT INTO readings (isolation_level, reading, unit_price)
SELECT 'READ COMMITTED', 'read 2', unit_price FROM relaks.product WHERE sku = 'BOOK-PINK';
COMMIT;
SELECT * FROM readings;                                   -- read 1 = 10000, read 2 = 8000 !
-- NON-REPEATABLE READ: the same query in the same transaction gave two
-- different answers, because READ COMMITTED takes a new snapshot for
-- every statement.


-- ############ PART 2: REPEATABLE READ ############

-- ===== STEP 4a (Tab A): reset, run ON ITS OWN =====
CALL relaks.p3_reset();                                   -- Pink back to ₦10,000
TRUNCATE readings;


-- ===== STEP 4b (Tab A): start the report again =====
BEGIN ISOLATION LEVEL REPEATABLE READ;
INSERT INTO readings (isolation_level, reading, unit_price)
SELECT 'REPEATABLE READ', 'read 1', unit_price FROM relaks.product WHERE sku = 'BOOK-PINK';
SELECT * FROM readings;                                   -- read 1 = 10000


-- ===== STEP 5 (Tab B): admin changes the price again =====
UPDATE relaks.product SET unit_price = 8000 WHERE sku = 'BOOK-PINK';


-- ===== STEP 6 (Tab A): read again =====
INSERT INTO readings (isolation_level, reading, unit_price)
SELECT 'REPEATABLE READ', 'read 2', unit_price FROM relaks.product WHERE sku = 'BOOK-PINK';
SELECT * FROM readings;                                   -- read 1 = 10000, read 2 = STILL 10000
-- REPEATABLE READ keeps ONE snapshot for the whole transaction, so the
-- report stays consistent even though the price really is 8000 now.


-- ===== STEP 7 (Tab A): try to write to the row that changed =====
UPDATE relaks.product SET stock_qty = stock_qty - 1 WHERE sku = 'BOOK-PINK';
-- ERROR: could not serialize access due to concurrent update
-- REPEATABLE READ refuses to update a row that changed after its snapshot
-- was taken. This is how it prevents lost updates: the application must
-- roll back and retry with fresh data.
ROLLBACK;
