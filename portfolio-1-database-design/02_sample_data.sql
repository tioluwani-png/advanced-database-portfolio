-- =====================================================================
-- Portfolio 1 — 02_sample_data.sql
-- Small, hand-written SIMULATED dataset for Relaks. All customer names,
-- emails, phones and addresses are fictional. Product names and prices
-- follow the real Relaks catalogue.
-- Run after 01_schema.sql:  psql -U postgres -d relaks -f 02_sample_data.sql
-- =====================================================================
SET search_path TO relaks;

-- Delivery zones (Lagos only; ₦2,000 – ₦5,000)
INSERT INTO delivery_zone (zone_name, delivery_fee) VALUES
  ('Yaba / Surulere',      2000),
  ('Ikeja / Maryland',     2500),
  ('Lekki Phase 1 / VI',   3500),
  ('Ajah / Sangotedo',     4500),
  ('Ikorodu',              5000);

-- Distributors outside Lagos (contact names are placeholders)
INSERT INTO distributor (city, contact_name, phone, wholesale_price) VALUES
  ('Kano',          'Kano Distributor',    '08000000001', 6500),
  ('Abuja',         'Abuja Distributor',   '08000000002', 6500),
  ('Port Harcourt', 'PH Distributor',      '08000000003', 6500),
  ('Ibadan',        'Ibadan Distributor',  '08000000004', 6500);

INSERT INTO product_category (category_name) VALUES
  ('coloring_book'), ('stationery'), ('bag'), ('combo');

-- Products: the three editions, stationery, a bag, and two combos
INSERT INTO product (sku, product_name, category_id, unit_price, stock_qty) VALUES
  ('BOOK-PINK',     'Relaks Coloring Book — Pink Edition',     1, 10000, 120),
  ('BOOK-TEAL',     'Relaks Coloring Book — Teal Edition',     1, 10000,  95),
  ('BOOK-LAV',      'Relaks Coloring Book — Lavender Edition', 1, 10000,   3),
  ('PENCIL-24',     '24 Colored Pencils',                      2,  4000, 200),
  ('FELT-24',       '24 Felt Pens',                            2,  5000, 150),
  ('TOTE-RLX',      'Relaks Tote Bag',                         3,  8000,  60),
  ('COMBO-25K',     '₦25k Combo (1 book + tote bag + pencils)',4, 25000,  40),
  ('COMBO-32K',     '₦32k Combo (2 books + pencils + felt pens)',4,32000, 40);

-- Combo contents (COMBO-25K uses Pink as its default book)
INSERT INTO combo_item (combo_product_id, component_product_id, quantity) VALUES
  (7, 1, 1), (7, 6, 1), (7, 4, 1),
  (8, 1, 1), (8, 2, 1), (8, 4, 1), (8, 5, 1);

INSERT INTO promotion (promo_code, description, discount_percent, free_delivery, starts_at, ends_at) VALUES
  ('BFFREEDEL', 'Black Friday week 1 — free Lagos delivery', 0,  TRUE,  '2026-11-06', '2026-11-09'),
  ('BF20',      'Black Friday week 2 — 20% off',            20, FALSE, '2026-11-13', '2026-11-16'),
  ('BF40',      'Black Friday finale — 40% off',            40, FALSE, '2026-11-27', '2026-11-30');

-- Customers (fictional)
INSERT INTO customer (full_name, email, phone, country, id_verification_status) VALUES
  ('Adaeze Okafor',     'adaeze.okafor@example.com',   '08011110001', 'Nigeria',      'verified'),
  ('Tunde Bakare',      'tunde.bakare@example.com',    '08011110002', 'Nigeria',      'not_started'),
  ('Zainab Bello',      'zainab.bello@example.com',    '08011110003', 'Nigeria',      'verified'),
  ('Chidi Nwosu',       'chidi.nwosu@example.com',     '08011110004', 'Nigeria',      'pending'),
  ('Funmi Adeyemi',     'funmi.adeyemi@example.com',   '08011110005', 'Nigeria',      'not_started'),
  ('Wanjiru Kamau',     'wanjiru.kamau@example.com',   '0700111006',  'Kenya',        'not_started'),
  ('Ifeoma Eze',        'ifeoma.eze@example.com',      '08011110007', 'Nigeria',      'verified'),
  ('Kemi Lawal',        'kemi.lawal@example.com',      '08011110008', 'Nigeria',      'failed');

INSERT INTO address (customer_id, label, street, zone_id, is_default) VALUES
  (1, 'home',   '12 Herbert Macaulay Way',  1, TRUE),
  (1, 'office', '4 Adeola Odeku Street',    3, FALSE),
  (2, 'home',   '7 Allen Avenue',           2, TRUE),
  (3, 'home',   '21 Admiralty Way',         3, TRUE),
  (4, 'home',   '3 Abraham Adesanya Road',  4, TRUE),
  (5, 'home',   '15 Ebute Road',            5, TRUE),
  (7, 'home',   '9 Bode Thomas Street',     1, TRUE),
  (8, 'home',   '30 Opebi Road',            2, TRUE);

-- Orders
INSERT INTO customer_order (customer_id, address_id, promo_id, sales_channel, order_status, delivery_fee, ordered_at) VALUES
  (1, 1, NULL, 'website',   'delivered',  2000, '2026-10-02 10:15+01'),
  (2, 3, NULL, 'instagram', 'delivered',  2500, '2026-10-05 18:40+01'),
  (3, 4, NULL, 'whatsapp',  'dispatched', 3500, '2026-10-20 12:05+01'),
  (1, 2, 1,    'website',   'paid',       0,    '2026-11-07 09:30+01'),
  (5, 6, 1,    'tiktok',    'paid',       0,    '2026-11-08 21:10+01'),
  (7, 7, NULL, 'website',   'pending',    2000, '2026-11-10 08:00+01'),
  (8, 8, NULL, 'x',         'cancelled',  2500, '2026-10-28 14:22+01');

INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_purchase) VALUES
  (1, 1, 1, 10000), (1, 4, 1, 4000),
  (2, 8, 1, 32000),
  (3, 2, 2, 10000), (3, 5, 1, 5000),
  (4, 7, 1, 25000),
  (5, 3, 1, 10000), (5, 1, 1, 10000),
  (6, 2, 1, 10000),
  (7, 6, 1, 8000);

-- Payments (order 7 failed then was cancelled; order 6 not yet paid)
INSERT INTO payment (order_id, paystack_reference, amount, payment_status, paid_at) VALUES
  (1, 'RLX-PSK-0001', 16000, 'success', '2026-10-02 10:16+01'),
  (2, 'RLX-PSK-0002', 34500, 'success', '2026-10-05 18:41+01'),
  (3, 'RLX-PSK-0003', 28500, 'success', '2026-10-20 12:06+01'),
  (4, 'RLX-PSK-0004', 25000, 'success', '2026-11-07 09:31+01'),
  (5, 'RLX-PSK-0005', 20000, 'success', '2026-11-08 21:11+01'),
  (7, 'RLX-PSK-0006', 10500, 'failed',  NULL);

INSERT INTO delivery (order_id, rider_name, delivery_status, dispatched_at, delivered_at) VALUES
  (1, 'Rider A', 'delivered',  '2026-10-03 09:00+01', '2026-10-03 13:20+01'),
  (2, 'Rider B', 'delivered',  '2026-10-06 10:00+01', '2026-10-06 15:45+01'),
  (3, 'Rider A', 'in_transit', '2026-10-21 09:30+01', NULL),
  (4, NULL,      'awaiting',   NULL, NULL),
  (5, NULL,      'awaiting',   NULL, NULL);

-- Reading Club
INSERT INTO rental_plan (plan_name, books_allowed, price, delivery_fee, duration_days) VALUES
  ('Monthly',   2,  8000, 6000, 30),
  ('Quarterly', 5, 22500, 6000, 90);

INSERT INTO rental_book (title, author, genre, copies_total) VALUES
  ('Things Fall Apart',           'Chinua Achebe',          'Fiction',     4),
  ('Purple Hibiscus',             'Chimamanda Ngozi Adichie','Fiction',    3),
  ('Atomic Habits',               'James Clear',            'Self-help',   5),
  ('The Psychology of Money',     'Morgan Housel',          'Finance',     3),
  ('Stay With Me',                'Ayobami Adebayo',        'Fiction',     2),
  ('Born a Crime',                'Trevor Noah',            'Memoir',      2);

INSERT INTO rental_subscription (customer_id, plan_id, start_date, end_date, sub_status, auto_renew) VALUES
  (1, 1, '2026-10-01', '2026-10-31', 'expired', FALSE),
  (1, 1, '2026-11-01', '2026-12-01', 'active',  TRUE),
  (3, 2, '2026-09-15', '2026-12-14', 'active',  FALSE),
  (7, 1, '2026-10-20', '2026-11-19', 'active',  FALSE);

INSERT INTO rental_loan (subscription_id, rental_book_id, delivered_on, due_on, returned_on) VALUES
  (1, 1, '2026-10-02', '2026-10-31', '2026-10-30'),
  (1, 3, '2026-10-02', '2026-10-31', '2026-10-30'),
  (2, 2, '2026-11-02', '2026-12-01', NULL),
  (2, 4, '2026-11-02', '2026-12-01', NULL),
  (3, 1, '2026-09-16', '2026-12-14', NULL),
  (3, 3, '2026-09-16', '2026-12-14', NULL),
  (3, 5, '2026-09-16', '2026-12-14', NULL),
  (3, 6, '2026-09-16', '2026-12-14', NULL),
  (3, 4, '2026-09-16', '2026-12-14', NULL),
  (4, 3, '2026-10-21', '2026-11-19', NULL),
  (4, 5, '2026-10-21', '2026-11-19', NULL);
