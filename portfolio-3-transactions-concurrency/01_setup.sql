-- =====================================================================
-- MIT 8103 Advanced Database Systems — Portfolio 3
-- File: 01_setup.sql
-- Helpers for the transaction and concurrency demonstrations.
--
-- Scenario: Relaks Black Friday FINALE (promo BF40, 40% off).
-- Only ONE Lavender Edition copy is left in stock.
--
-- Run once (any Query Tool tab), after the Portfolio 1 scripts.
-- =====================================================================
SET search_path TO relaks;

-- ---------------------------------------------------------------------
-- p3_reset(): puts the demo back to its starting state so every
-- scenario can be re-run cleanly.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE relaks.p3_reset()
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM relaks.payment
    WHERE paystack_reference LIKE 'P3-%';

    DELETE FROM relaks.customer_order                 -- order_item and delivery cascade
    WHERE promo_id = (SELECT promo_id FROM relaks.promotion WHERE promo_code = 'BF40');

    UPDATE relaks.product SET stock_qty = 1     WHERE sku = 'BOOK-LAV';   -- the last copy
    UPDATE relaks.product SET stock_qty = 95    WHERE sku = 'BOOK-TEAL';
    UPDATE relaks.product SET stock_qty = 60    WHERE sku = 'TOTE-RLX';
    UPDATE relaks.product SET stock_qty = 120,
                              unit_price = 10000 WHERE sku = 'BOOK-PINK';
END $$;

-- ---------------------------------------------------------------------
-- p3_create_order(): what the Relaks checkout does after the stock
-- decision has been made: creates the order, its line (40% off) and a
-- successful Paystack payment, in whatever transaction it is called from.
-- It does NOT touch stock: each scenario handles stock itself, because
-- that is exactly where the concurrency problems happen.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION relaks.p3_create_order(p_customer INT, p_sku TEXT, p_ref TEXT)
RETURNS INT
LANGUAGE plpgsql AS $$
DECLARE
    v_order   INT;
    v_addr    INT;
    v_fee     NUMERIC;
    v_prod    INT;
    v_price   NUMERIC;
BEGIN
    SELECT a.address_id, z.delivery_fee INTO v_addr, v_fee
    FROM relaks.address a JOIN relaks.delivery_zone z ON z.zone_id = a.zone_id
    WHERE a.customer_id = p_customer AND a.is_default;

    SELECT product_id, unit_price * 0.60 INTO v_prod, v_price      -- BF40: 40% off
    FROM relaks.product WHERE sku = p_sku;

    INSERT INTO relaks.customer_order (customer_id, address_id, promo_id, sales_channel,
                                       order_status, delivery_fee, ordered_at)
    VALUES (p_customer, v_addr,
            (SELECT promo_id FROM relaks.promotion WHERE promo_code = 'BF40'),
            'website', 'paid', v_fee, TIMESTAMPTZ '2026-11-27 20:00+01')
    RETURNING order_id INTO v_order;

    INSERT INTO relaks.order_item (order_id, product_id, quantity, unit_price_at_purchase)
    VALUES (v_order, v_prod, 1, v_price);

    INSERT INTO relaks.payment (order_id, paystack_reference, amount, payment_status, paid_at)
    VALUES (v_order, p_ref, v_price + v_fee, 'success', now());

    RETURN v_order;
END $$;

-- ---------------------------------------------------------------------
-- lavender_status: the one view every concurrency scenario ends with.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW relaks.lavender_status AS
WITH bf40_lavender AS (
    SELECT o.order_id, c.full_name
    FROM relaks.customer_order o
    JOIN relaks.order_item oi ON oi.order_id = o.order_id
    JOIN relaks.product pr    ON pr.product_id = oi.product_id AND pr.sku = 'BOOK-LAV'
    JOIN relaks.customer c    ON c.customer_id = o.customer_id
    WHERE o.promo_id = (SELECT promo_id FROM relaks.promotion WHERE promo_code = 'BF40')
)
SELECT p.stock_qty                                              AS lavender_copies_left,
       (SELECT COUNT(*) FROM bf40_lavender)                     AS paid_bf40_lavender_orders,
       (SELECT STRING_AGG(full_name, ', ' ORDER BY order_id) FROM bf40_lavender) AS buyers,
       CASE (SELECT COUNT(*) FROM bf40_lavender)
            WHEN 0 THEN 'No sale yet'
            WHEN 1 THEN 'Correct: 1 copy, 1 buyer'
            ELSE 'OVERSOLD: ' || (SELECT COUNT(*) FROM bf40_lavender) || ' customers paid for 1 copy'
       END                                                      AS verdict
FROM relaks.product p
WHERE p.sku = 'BOOK-LAV';

-- ---------------------------------------------------------------------
-- lock_monitor: run from a THIRD tab to watch sessions waiting on locks.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW relaks.lock_monitor AS
SELECT pid,
       state,
       wait_event_type,
       wait_event,
       pg_blocking_pids(pid)                    AS blocked_by_pid,
       date_trunc('second', now() - xact_start) AS in_transaction_for,
       left(regexp_replace(query, '\s+', ' ', 'g'), 90) AS current_statement
FROM pg_stat_activity
WHERE datname = 'relaks'
  AND pid <> pg_backend_pid()
  AND state <> 'idle'
ORDER BY xact_start;

CALL relaks.p3_reset();
SELECT * FROM relaks.lavender_status;
