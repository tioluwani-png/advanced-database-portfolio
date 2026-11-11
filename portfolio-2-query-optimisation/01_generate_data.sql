-- =====================================================================
-- MIT 8103 Advanced Database Systems — Portfolio 2
-- File: 01_generate_data.sql
-- Scales the Portfolio 1 Relaks database up to a realistic size so that
-- indexing makes a measurable difference. All rows are SIMULATED.
--
--   ~50,000 customers and addresses
--   ~300,000 orders and ~600,000 order lines
--   ~300,000 Paystack payments
--   ~20,000 Reading Club subscriptions and ~100,000 book loans
--
-- Requires: Portfolio 1 scripts already run (schema + sample data).
-- Safe to re-run: it stops if the data has already been generated.
-- Took about 3 minutes on my laptop.
-- =====================================================================
SET search_path TO relaks;

DO $$
DECLARE
    v_first INT;   -- id of the first generated customer (ids can have gaps,
                   -- e.g. after the Portfolio 1 constraint tests, so never assume them)
BEGIN
    IF (SELECT COUNT(*) FROM customer) > 1000 THEN
        RAISE NOTICE 'Data already generated (% customers) - nothing to do.',
                     (SELECT COUNT(*) FROM customer);
        RETURN;
    END IF;

    PERFORM setseed(0.8103);   -- same "random" data every time

    -- 50,000 generated customers (the 8 hand-written Portfolio 1 customers stay)
    INSERT INTO customer (full_name, email, phone, country, id_verification_status, created_at)
    SELECT 'Customer ' || n,
           'customer' || n || '@example.com',
           '080' || lpad(n::text, 8, '0'),
           CASE WHEN n % 50 = 0 THEN 'Kenya' WHEN n % 97 = 0 THEN 'United Kingdom' ELSE 'Nigeria' END,
           CASE WHEN n % 3 = 0 THEN 'verified' ELSE 'not_started' END,
           TIMESTAMPTZ '2025-06-01' + (random() * 500) * INTERVAL '1 day'
    FROM generate_series(1, 50000) AS n;

    SELECT MIN(customer_id) INTO v_first
    FROM customer WHERE email LIKE 'customer%@example.com';

    -- One default address per new customer, spread over the 5 Lagos zones
    INSERT INTO address (customer_id, label, street, zone_id, is_default)
    SELECT c.customer_id, 'home', (c.customer_id % 300 + 1) || ' Example Street', (c.customer_id % 5) + 1, TRUE
    FROM customer c
    WHERE c.customer_id >= v_first;

    -- 300,000 orders across Nov 2025 – Nov 2026
    INSERT INTO customer_order (customer_id, address_id, promo_id, sales_channel, order_status, delivery_fee, ordered_at)
    SELECT a.customer_id,
           a.address_id,
           NULL,
           (ARRAY['website','instagram','whatsapp','tiktok','x'])[1 + floor(random() * 5)::int],
           CASE WHEN r < 0.85 THEN 'delivered'
                WHEN r < 0.90 THEN 'cancelled'
                WHEN r < 0.95 THEN 'dispatched'
                WHEN r < 0.98 THEN 'paid'
                ELSE 'pending' END,
           z.delivery_fee,
           TIMESTAMPTZ '2025-11-10' + (random() * 365) * INTERVAL '1 day'
    FROM (
        SELECT n, random() AS r, v_first + floor(random() * 50000)::int AS cust
        FROM generate_series(1, 300000) AS n
    ) g
    JOIN address a        ON a.customer_id = g.cust AND a.is_default
    JOIN delivery_zone z  ON z.zone_id = a.zone_id;

    -- 1–3 distinct products per order (product ids 1–8 from Portfolio 1)
    INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_purchase)
    SELECT o.order_id, p.product_id, 1 + (o.order_id % 2), p.unit_price
    FROM customer_order o
    CROSS JOIN LATERAL (
        SELECT DISTINCT ((o.order_id + k * 3) % 8) + 1 AS pid
        FROM generate_series(0, o.order_id % 3) AS k
    ) pick
    JOIN product p ON p.product_id = pick.pid
    WHERE o.order_id > 7;

    -- One Paystack payment per non-pending order
    INSERT INTO payment (order_id, paystack_reference, amount, payment_status, paid_at)
    SELECT s.order_id,
           'RLX-PSK-' || lpad(s.order_id::text, 7, '0'),
           s.order_total,
           CASE WHEN s.order_status = 'cancelled' THEN 'failed' ELSE 'success' END,
           CASE WHEN s.order_status = 'cancelled' THEN NULL ELSE s.ordered_at + INTERVAL '2 minutes' END
    FROM order_summary s
    WHERE s.order_id > 7 AND s.order_status <> 'pending';

    -- Reading Club: 20,000 subscriptions, 5 loans each
    INSERT INTO rental_subscription (customer_id, plan_id, start_date, end_date, sub_status, auto_renew)
    SELECT c, 1 + (c % 2), d, d + CASE WHEN c % 2 = 0 THEN 30 ELSE 90 END,
           CASE WHEN d + 30 < DATE '2026-11-10' THEN 'expired' ELSE 'active' END, c % 4 = 0
    FROM (SELECT v_first + n AS c, DATE '2025-11-01' + (random() * 370)::int AS d
          FROM generate_series(0, 19999) AS n) s;

    INSERT INTO rental_loan (subscription_id, rental_book_id, delivered_on, due_on, returned_on)
    SELECT s.subscription_id,
           1 + ((s.subscription_id + k) % 6),
           s.start_date + 1,
           s.start_date + 31,
           CASE WHEN s.start_date + 31 >= DATE '2026-11-10' THEN NULL          -- still out, not yet due
                WHEN random() < 0.97 THEN s.start_date + 25                    -- returned on time
                ELSE NULL END                                                   -- overdue
    FROM rental_subscription s
    CROSS JOIN generate_series(1, 5) AS k
    WHERE s.subscription_id > 4;

    RAISE NOTICE 'Done: % customers, % orders, % order lines, % payments, % loans',
        (SELECT COUNT(*) FROM customer), (SELECT COUNT(*) FROM customer_order),
        (SELECT COUNT(*) FROM order_item), (SELECT COUNT(*) FROM payment),
        (SELECT COUNT(*) FROM rental_loan);
END $$;

-- Refresh planner statistics so the optimiser knows the new table sizes.
ANALYZE;

-- Show the new table sizes
SELECT 'customer' AS table_name, COUNT(*) AS row_count FROM relaks.customer
UNION ALL SELECT 'customer_order', COUNT(*) FROM relaks.customer_order
UNION ALL SELECT 'order_item',     COUNT(*) FROM relaks.order_item
UNION ALL SELECT 'payment',        COUNT(*) FROM relaks.payment
UNION ALL SELECT 'rental_loan',    COUNT(*) FROM relaks.rental_loan;
