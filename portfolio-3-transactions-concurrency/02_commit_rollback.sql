-- =====================================================================
-- Portfolio 3 — 02_commit_rollback.sql
-- COMMIT, ROLLBACK and SAVEPOINT in one Relaks checkout session.
-- Run the WHOLE file in one Query Tool tab (F5). The final table checks
-- that each transaction left the database exactly as it should.
-- =====================================================================
SET search_path TO relaks;
CALL relaks.p3_reset();

-- Remember stock levels before anything happens
DROP TABLE IF EXISTS stock_before;
CREATE TEMP TABLE stock_before AS
SELECT sku, stock_qty FROM relaks.product WHERE sku IN ('BOOK-TEAL', 'TOTE-RLX');

-- ---------------------------------------------------------------------
-- T1  COMMIT: Adaeze buys a Teal Edition. Order, line, payment and the
--     stock update succeed or fail TOGETHER (atomicity).
-- ---------------------------------------------------------------------
BEGIN;
    UPDATE relaks.product SET stock_qty = stock_qty - 1 WHERE sku = 'BOOK-TEAL';
    SELECT relaks.p3_create_order(1, 'BOOK-TEAL', 'P3-T1-COMMIT');
COMMIT;

-- ---------------------------------------------------------------------
-- T2  ROLLBACK: Tunde starts the same checkout, but Paystack declines his
--     card. The application issues ROLLBACK: the order, its line, the
--     payment row AND the stock change all disappear.
-- ---------------------------------------------------------------------
BEGIN;
    UPDATE relaks.product SET stock_qty = stock_qty - 1 WHERE sku = 'BOOK-TEAL';
    SELECT relaks.p3_create_order(2, 'BOOK-TEAL', 'P3-T2-DECLINED');
    -- ... Paystack webhook: charge.failed ...
ROLLBACK;

-- ---------------------------------------------------------------------
-- T3  SAVEPOINT: Zainab buys a Teal Edition, adds a tote bag, then
--     removes the bag before paying. ROLLBACK TO SAVEPOINT undoes ONLY
--     the tote bag; the rest of the order is kept and committed.
-- ---------------------------------------------------------------------
BEGIN;
    UPDATE relaks.product SET stock_qty = stock_qty - 1 WHERE sku = 'BOOK-TEAL';
    SELECT relaks.p3_create_order(3, 'BOOK-TEAL', 'P3-T3-SAVEPOINT');

    SAVEPOINT add_tote_bag;
        UPDATE relaks.product SET stock_qty = stock_qty - 1 WHERE sku = 'TOTE-RLX';
        INSERT INTO relaks.order_item (order_id, product_id, quantity, unit_price_at_purchase)
        SELECT p.order_id, (SELECT product_id FROM relaks.product WHERE sku = 'TOTE-RLX'), 1, 4800
        FROM relaks.payment p WHERE p.paystack_reference = 'P3-T3-SAVEPOINT';
    ROLLBACK TO SAVEPOINT add_tote_bag;      -- customer removed the bag
COMMIT;

-- ---------------------------------------------------------------------
-- RESULT: did each transaction do exactly what it should?
-- ---------------------------------------------------------------------
WITH t AS (
    SELECT (SELECT stock_qty FROM stock_before WHERE sku = 'BOOK-TEAL') AS teal_before,
           (SELECT stock_qty FROM relaks.product WHERE sku = 'BOOK-TEAL') AS teal_after,
           (SELECT stock_qty FROM stock_before WHERE sku = 'TOTE-RLX')  AS tote_before,
           (SELECT stock_qty FROM relaks.product WHERE sku = 'TOTE-RLX')  AS tote_after
), chk(test, expected, actual) AS (
    SELECT 'T1 COMMIT: Adaeze''s order and payment exist', '1',
           (SELECT COUNT(*) FROM relaks.payment WHERE paystack_reference = 'P3-T1-COMMIT')::text
    UNION ALL
    SELECT 'T2 ROLLBACK: Tunde''s declined order exists', '0',
           (SELECT COUNT(*) FROM relaks.payment WHERE paystack_reference = 'P3-T2-DECLINED')::text
    UNION ALL
    SELECT 'T3 SAVEPOINT: Zainab''s order exists', '1',
           (SELECT COUNT(*) FROM relaks.payment WHERE paystack_reference = 'P3-T3-SAVEPOINT')::text
    UNION ALL
    SELECT 'T3 SAVEPOINT: tote bag lines on Zainab''s order', '0',
           (SELECT COUNT(*) FROM relaks.order_item oi
            JOIN relaks.payment p ON p.order_id = oi.order_id
            JOIN relaks.product pr ON pr.product_id = oi.product_id
            WHERE p.paystack_reference = 'P3-T3-SAVEPOINT' AND pr.sku = 'TOTE-RLX')::text
    UNION ALL
    SELECT 'Teal stock: 2 sold (T1 + T3), T2 restored', (teal_before - 2)::text, teal_after::text FROM t
    UNION ALL
    SELECT 'Tote stock unchanged (rolled back to savepoint)', tote_before::text, tote_after::text FROM t
)
SELECT test, expected, actual,
       CASE WHEN expected = actual THEN 'PASS' ELSE 'FAIL' END AS result
FROM chk;
