// =====================================================================
// Portfolio 4 — 03_indexes_and_explain.js
// Indexes for the document model, measured with explain("executionStats").
// In Atlas Data Explorer: the "Explain" button on the Find bar shows the
// same plan visually; the "Indexes" tab creates the indexes.
// =====================================================================

use("relaks");

// ---------------------------------------------------------------- BEFORE
// "My orders" for customer 1 with no index: every order is read.
db.orders.find({ "customer.customer_id": 1 }).sort({ ordered_at: -1 })
  .explain("executionStats");
// Expect: COLLSCAN + SORT stage, totalDocsExamined = 1507, nReturned = 19

// ---------------------------------------------------------------- INDEXES
// 1. Compound index: equality field first, then the sort field, so the
//    results come out of the index already in order (no in-memory SORT).
db.orders.createIndex({ "customer.customer_id": 1, ordered_at: -1 }, { name: "customer_orders_newest" });

// 2. Multikey + unique index on an embedded array field: no two payment
//    attempts anywhere can share a Paystack reference. Same job as the
//    UNIQUE constraint on payment.paystack_reference in Portfolio 1, so a
//    retried webhook cannot be recorded twice.
db.orders.createIndex({ "payments.paystack_reference": 1 },
                      { name: "unique_paystack_reference", unique: true,
                        partialFilterExpression: { "payments.paystack_reference": { $exists: true } } });

// 3. Unique email for customers (Portfolio 1: email UNIQUE).
db.customers.createIndex({ email: 1 }, { name: "unique_email", unique: true });

// 4. Multikey index on an embedded array for "customers in a delivery zone".
db.customers.createIndex({ "addresses.zone": 1 }, { name: "address_zone" });

// ---------------------------------------------------------------- AFTER
db.orders.find({ "customer.customer_id": 1 }).sort({ ordered_at: -1 })
  .explain("executionStats");
// Expect: IXSCAN on customer_orders_newest, no SORT stage,
//         totalKeysExamined = 19, totalDocsExamined = 19, nReturned = 19

// ---------------------------------------------------------------- prove the unique index works
// Expected: E11000 duplicate key error (RLX-PSK-0001 already belongs to order 1).
db.orders.insertOne({
  _id: "RLX-ORD-TEST-DUP",
  customer: { customer_id: 2, name: "Tunde Bakare" },
  ship_to: { street: "7 Allen Avenue", zone: "Ikeja / Maryland", city: "Lagos" },
  sales_channel: "website", status: "paid", ordered_at: new Date(),
  items: [{ sku: "BOOK-PINK", name: "Relaks Coloring Book — Pink Edition", qty: 1, unit_price: 10000 }],
  items_subtotal: 10000, delivery_fee: 2500, order_total: 12500,
  payments: [{ paystack_reference: "RLX-PSK-0001", amount: 12500, status: "success", paid_at: new Date() }]
});
