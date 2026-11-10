-- =====================================================================
-- Portfolio 1 — 03_constraint_tests.sql
-- Proves that the keys and constraints in 01_schema.sql actually protect
-- the data. Each test tries something INVALID inside its own block; the
-- database must reject it. The block catches the error and reports
-- PASS (rejected, with PostgreSQL's own error message) or FAIL (accepted).
-- Works in pgAdmin's Query Tool (see the Messages tab) and in psql.
-- =====================================================================
SET search_path TO relaks;

DO $$
DECLARE
    tests_failed INT := 0;

BEGIN
    -- TEST 1: PRIMARY KEY — same product twice in one order
    BEGIN
        INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_purchase)
        VALUES (1, 1, 1, 10000);
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 1  FAIL — duplicate order line was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 1  PASS (primary key)        — %', SQLERRM;
    END;

    -- TEST 2: UNIQUE — two customers with the same email
    BEGIN
        INSERT INTO customer (full_name, email, phone)
        VALUES ('Copy Cat', 'adaeze.okafor@example.com', '08099999999');
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 2  FAIL — duplicate email was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 2  PASS (unique email)       — %', SQLERRM;
    END;

    -- TEST 3: FOREIGN KEY — order for a customer that does not exist
    BEGIN
        INSERT INTO customer_order (customer_id, address_id, sales_channel, delivery_fee)
        VALUES (9999, 1, 'website', 2000);
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 3  FAIL — order for unknown customer was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 3  PASS (foreign key)        — %', SQLERRM;
    END;

    -- TEST 4: CHECK — stock can never go negative (overselling)
    BEGIN
        UPDATE product SET stock_qty = stock_qty - 10 WHERE sku = 'BOOK-LAV';  -- only 3 in stock
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 4  FAIL — stock went negative';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 4  PASS (no overselling)     — %', SQLERRM;
    END;

    -- TEST 5: CHECK — unknown sales channel
    BEGIN
        INSERT INTO customer_order (customer_id, address_id, sales_channel, delivery_fee)
        VALUES (1, 1, 'facebook', 2000);
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 5  FAIL — unknown channel was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 5  PASS (channel check)      — %', SQLERRM;
    END;

    -- TEST 6: UNIQUE — the same Paystack reference applied twice (duplicate webhook)
    BEGIN
        INSERT INTO payment (order_id, paystack_reference, amount, payment_status, paid_at)
        VALUES (1, 'RLX-PSK-0001', 16000, 'success', now());
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 6  FAIL — duplicate Paystack reference was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 6  PASS (duplicate webhook)  — %', SQLERRM;
    END;

    -- TEST 7: PARTIAL UNIQUE INDEX — a second default address for one customer
    BEGIN
        INSERT INTO address (customer_id, street, zone_id, is_default)
        VALUES (1, '1 Test Street', 1, TRUE);
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 7  FAIL — second default address was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 7  PASS (one default addr)   — %', SQLERRM;
    END;

    -- TEST 8: CHECK — promo that ends before it starts
    BEGIN
        INSERT INTO promotion (promo_code, discount_percent, starts_at, ends_at)
        VALUES ('BADPROMO', 10, '2026-12-10', '2026-12-01');
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 8  FAIL — backwards promo dates were accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 8  PASS (promo dates)        — %', SQLERRM;
    END;

    -- TEST 9: CHECK — a combo that contains itself
    BEGIN
        INSERT INTO combo_item (combo_product_id, component_product_id, quantity)
        VALUES (7, 7, 1);
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 9  FAIL — self-referencing combo was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 9  PASS (combo self-ref)     — %', SQLERRM;
    END;

    -- TEST 10: FK RESTRICT — deleting a product that appears in past orders
    BEGIN
        DELETE FROM product WHERE sku = 'BOOK-LAV';   -- appears in order 5
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 10 FAIL — product with order history was deleted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 10 PASS (keep history)       — %', SQLERRM;
    END;

    -- TEST 11: 1:1 — a second delivery record for the same order
    BEGIN
        INSERT INTO delivery (order_id) VALUES (1);
        tests_failed := tests_failed + 1;
        RAISE NOTICE 'TEST 11 FAIL — second delivery for one order was accepted';
    EXCEPTION WHEN others THEN
        RAISE NOTICE 'TEST 11 PASS (1:1 delivery)       — %', SQLERRM;
    END;

    RAISE NOTICE '-----------------------------------------------';
    RAISE NOTICE 'RESULT: % of 11 constraint tests passed', 11 - tests_failed;
END $$;

-- Data is unchanged after all the attempts:
SELECT (SELECT stock_qty FROM product WHERE sku = 'BOOK-LAV') AS lavender_stock_still_3,
       (SELECT COUNT(*)  FROM customer)                       AS customers_still_8,
       (SELECT COUNT(*)  FROM product)                        AS products_still_8;
