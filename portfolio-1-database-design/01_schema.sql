-- =====================================================================
-- MIT 8103 Advanced Database Systems — Portfolio 1
-- Case study: Relaks (coloring books, stationery & Reading Club rentals)
-- File: 01_schema.sql  — creates the full relational schema (PostgreSQL 16+)
--
-- Run:  psql -U postgres -c "CREATE DATABASE relaks;"
--       psql -U postgres -d relaks -f 01_schema.sql
-- =====================================================================

-- Start clean so the script can be re-run while testing.
DROP SCHEMA IF EXISTS relaks CASCADE;
CREATE SCHEMA relaks;
SET search_path TO relaks;

-- ---------------------------------------------------------------------
-- 1. LOOKUP / REFERENCE TABLES
-- ---------------------------------------------------------------------

-- Lagos delivery zones. Fees differ by area (₦2,000 – ₦5,000).
CREATE TABLE delivery_zone (
    zone_id        INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    zone_name      VARCHAR(60)   NOT NULL UNIQUE,          -- e.g. 'Lagos Mainland'
    city           VARCHAR(60)   NOT NULL DEFAULT 'Lagos',
    delivery_fee   NUMERIC(10,2) NOT NULL CHECK (delivery_fee >= 0)
);

-- Distributors serve customers outside Lagos (Kano, Abuja, PH, Ibadan).
CREATE TABLE distributor (
    distributor_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city             VARCHAR(60)   NOT NULL UNIQUE,          -- one distributor per city
    contact_name     VARCHAR(100)  NOT NULL,
    phone            VARCHAR(20)   NOT NULL,
    wholesale_price  NUMERIC(10,2) NOT NULL CHECK (wholesale_price > 0),
    is_active        BOOLEAN       NOT NULL DEFAULT TRUE
);

CREATE TABLE product_category (
    category_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name  VARCHAR(40) NOT NULL UNIQUE                -- coloring_book, stationery, bag, combo
);

-- ---------------------------------------------------------------------
-- 2. CUSTOMERS
-- ---------------------------------------------------------------------

CREATE TABLE customer (
    customer_id    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name      VARCHAR(100) NOT NULL,
    email          VARCHAR(150) NOT NULL UNIQUE,
    phone          VARCHAR(20)  NOT NULL,
    country        VARCHAR(60)  NOT NULL DEFAULT 'Nigeria',
    -- Reading Club renters must pass ID verification (done by an external
    -- provider). Only the RESULT is stored, never the ID number itself.
    id_verification_status VARCHAR(12) NOT NULL DEFAULT 'not_started'
        CHECK (id_verification_status IN ('not_started','pending','verified','failed')),
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CHECK (email LIKE '%_@_%._%')
);

-- A customer can save several delivery addresses (home, office ...).
CREATE TABLE address (
    address_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    INT NOT NULL REFERENCES customer(customer_id) ON DELETE CASCADE,
    label          VARCHAR(30)  NOT NULL DEFAULT 'home',
    street         VARCHAR(200) NOT NULL,
    zone_id        INT          NOT NULL REFERENCES delivery_zone(zone_id),
    is_default     BOOLEAN      NOT NULL DEFAULT FALSE
);
-- At most ONE default address per customer (partial unique index).
CREATE UNIQUE INDEX one_default_address_per_customer
    ON address (customer_id) WHERE is_default;

-- ---------------------------------------------------------------------
-- 3. PRODUCTS & COMBOS
-- ---------------------------------------------------------------------

CREATE TABLE product (
    product_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku            VARCHAR(30)   NOT NULL UNIQUE,            -- e.g. 'BOOK-PINK'
    product_name   VARCHAR(120)  NOT NULL,
    category_id    INT           NOT NULL REFERENCES product_category(category_id),
    unit_price     NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    stock_qty      INT           NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),  -- can never oversell below 0
    is_active      BOOLEAN       NOT NULL DEFAULT TRUE
);

-- A combo (e.g. "₦32k combo") is itself a product made of other products.
-- Many-to-many self-relationship on PRODUCT, resolved by this junction table.
CREATE TABLE combo_item (
    combo_product_id     INT NOT NULL REFERENCES product(product_id) ON DELETE CASCADE,
    component_product_id INT NOT NULL REFERENCES product(product_id),
    quantity             INT NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (combo_product_id, component_product_id),
    CHECK (combo_product_id <> component_product_id)        -- a combo cannot contain itself
);

-- Black Friday / seasonal promo codes.
CREATE TABLE promotion (
    promo_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    promo_code        VARCHAR(30)  NOT NULL UNIQUE,
    description       VARCHAR(200),
    discount_percent  NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 100),
    free_delivery     BOOLEAN      NOT NULL DEFAULT FALSE,
    starts_at         TIMESTAMPTZ  NOT NULL,
    ends_at           TIMESTAMPTZ  NOT NULL,
    CHECK (ends_at > starts_at)
);

-- ---------------------------------------------------------------------
-- 4. ORDERS, PAYMENTS, DELIVERY
-- ---------------------------------------------------------------------

CREATE TABLE customer_order (
    order_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id    INT NOT NULL REFERENCES customer(customer_id),
    address_id     INT NOT NULL REFERENCES address(address_id),
    promo_id       INT          REFERENCES promotion(promo_id),   -- optional
    sales_channel  VARCHAR(15)  NOT NULL
        CHECK (sales_channel IN ('website','instagram','whatsapp','tiktok','x')),
    order_status   VARCHAR(15)  NOT NULL DEFAULT 'pending'
        CHECK (order_status IN ('pending','paid','dispatched','delivered','cancelled')),
    delivery_fee   NUMERIC(10,2) NOT NULL CHECK (delivery_fee >= 0),  -- copied at checkout
    ordered_at     TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Line items: which products are in which order (resolves the M:N
-- between CUSTOMER_ORDER and PRODUCT).
CREATE TABLE order_item (
    order_id       INT NOT NULL REFERENCES customer_order(order_id) ON DELETE CASCADE,
    product_id     INT NOT NULL REFERENCES product(product_id),
    quantity       INT NOT NULL CHECK (quantity > 0),
    -- Price is copied at the moment of purchase so that a later price change
    -- (or a Black Friday discount ending) does not rewrite old receipts.
    unit_price_at_purchase NUMERIC(10,2) NOT NULL CHECK (unit_price_at_purchase >= 0),
    PRIMARY KEY (order_id, product_id)
);

-- One order can have several payment attempts (e.g. a card is declined,
-- the customer retries). Each attempt has its own Paystack reference.
CREATE TABLE payment (
    payment_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id            INT NOT NULL REFERENCES customer_order(order_id),
    paystack_reference  VARCHAR(50)   NOT NULL UNIQUE,      -- stops the same webhook being applied twice
    amount              NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    payment_status      VARCHAR(10)   NOT NULL
        CHECK (payment_status IN ('initiated','success','failed','refunded')),
    paid_at             TIMESTAMPTZ
);

-- One delivery record per order (1:1, enforced by UNIQUE on order_id).
CREATE TABLE delivery (
    delivery_id      INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id         INT NOT NULL UNIQUE REFERENCES customer_order(order_id) ON DELETE CASCADE,
    rider_name       VARCHAR(100),
    delivery_status  VARCHAR(12) NOT NULL DEFAULT 'awaiting'
        CHECK (delivery_status IN ('awaiting','picked_up','in_transit','delivered','failed')),
    dispatched_at    TIMESTAMPTZ,
    delivered_at     TIMESTAMPTZ,
    CHECK (delivered_at IS NULL OR dispatched_at IS NULL OR delivered_at >= dispatched_at)
);

-- ---------------------------------------------------------------------
-- 5. READING CLUB (book rentals)
-- ---------------------------------------------------------------------

CREATE TABLE rental_plan (
    plan_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plan_name       VARCHAR(30)   NOT NULL UNIQUE,           -- 'Monthly', 'Quarterly'
    books_allowed   INT           NOT NULL CHECK (books_allowed > 0),
    price           NUMERIC(10,2) NOT NULL CHECK (price > 0),
    delivery_fee    NUMERIC(10,2) NOT NULL CHECK (delivery_fee >= 0),
    duration_days   INT           NOT NULL CHECK (duration_days > 0)
);

CREATE TABLE rental_book (
    rental_book_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title           VARCHAR(200) NOT NULL,
    author          VARCHAR(150) NOT NULL,
    genre           VARCHAR(60),
    copies_total    INT NOT NULL CHECK (copies_total >= 0),
    UNIQUE (title, author)
);

CREATE TABLE rental_subscription (
    subscription_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    customer_id     INT  NOT NULL REFERENCES customer(customer_id),
    plan_id         INT  NOT NULL REFERENCES rental_plan(plan_id),
    start_date      DATE NOT NULL,
    end_date        DATE NOT NULL,
    sub_status      VARCHAR(10) NOT NULL DEFAULT 'active'
        CHECK (sub_status IN ('active','expired','cancelled')),
    auto_renew      BOOLEAN NOT NULL DEFAULT FALSE,
    CHECK (end_date > start_date)
);

-- Each physical loan of a book under a subscription.
CREATE TABLE rental_loan (
    loan_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_id  INT  NOT NULL REFERENCES rental_subscription(subscription_id),
    rental_book_id   INT  NOT NULL REFERENCES rental_book(rental_book_id),
    delivered_on     DATE NOT NULL,
    due_on           DATE NOT NULL,
    returned_on      DATE,
    CHECK (due_on > delivered_on),
    CHECK (returned_on IS NULL OR returned_on >= delivered_on)
);

-- ---------------------------------------------------------------------
-- 6. HELPER VIEW — order totals are DERIVED, not stored (avoids update
--    anomalies; see normalisation notes in README).
-- ---------------------------------------------------------------------
CREATE VIEW order_summary AS
SELECT  o.order_id,
        o.customer_id,
        o.ordered_at,
        o.order_status,
        SUM(oi.quantity * oi.unit_price_at_purchase)                       AS items_subtotal,
        o.delivery_fee,
        SUM(oi.quantity * oi.unit_price_at_purchase) + o.delivery_fee      AS order_total
FROM    customer_order o
JOIN    order_item oi ON oi.order_id = o.order_id
GROUP BY o.order_id;

-- Foreign-key columns PostgreSQL does NOT index automatically.
CREATE INDEX ix_address_customer        ON address(customer_id);
CREATE INDEX ix_order_customer          ON customer_order(customer_id);
CREATE INDEX ix_order_item_product      ON order_item(product_id);
CREATE INDEX ix_payment_order           ON payment(order_id);
CREATE INDEX ix_subscription_customer   ON rental_subscription(customer_id);
CREATE INDEX ix_loan_subscription       ON rental_loan(subscription_id);
