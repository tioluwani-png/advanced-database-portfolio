// =====================================================================
// Portfolio 4 — 01_collections_and_validation.js
// MongoDB (Atlas) — database "relaks"
//
// Creates the four collections with JSON Schema validation, so MongoDB
// rejects bad documents in the same way the CHECK constraints did in
// PostgreSQL (Portfolio 1). Written for mongosh. In this portfolio the same
// rules were pasted into each collection's "Validation" tab in Atlas Data
// Explorer (Action: Error, Level: Strict), after the data was loaded.
// =====================================================================

use("relaks");

// ---------------------------------------------------------------- orders
// An order is ONE document: line items, delivery address, promo, payment
// attempts and delivery are embedded, because they are always read together
// and never change once the order is placed.
db.createCollection("orders", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "customer", "ship_to", "sales_channel", "status",
               "ordered_at", "items", "order_total", "payments"],
    properties: {
      customer: {
        bsonType: "object",
        required: ["customer_id", "name"],
        properties: { customer_id: { bsonType: "number" }, name: { bsonType: "string" } }
      },
      sales_channel: { enum: ["website", "instagram", "whatsapp", "tiktok", "x"] },
      status:        { enum: ["pending", "paid", "dispatched", "delivered", "cancelled"] },
      ordered_at:    { bsonType: "date" },
      items: {
        bsonType: "array",
        minItems: 1,                                    // an order must contain something
        items: {
          bsonType: "object",
          required: ["sku", "qty", "unit_price"],
          properties: {
            sku:        { bsonType: "string" },
            qty:        { bsonType: "number", minimum: 1 },
            unit_price: { bsonType: "number", minimum: 0 }
          }
        }
      },
      delivery_fee: { bsonType: "number", minimum: 0 },
      order_total:  { bsonType: "number", minimum: 0 },
      payments: {
        bsonType: "array",
        items: {
          bsonType: "object",
          required: ["paystack_reference", "amount", "status"],
          properties: {
            amount: { bsonType: "number", minimum: 0 },
            status: { enum: ["initiated", "success", "failed", "refunded"] }
          }
        }
      }
    }
  } },
  validationLevel: "strict",
  validationAction: "error"
});

// ---------------------------------------------------------------- products
db.createCollection("products", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "name", "category", "price", "stock_qty"],
    properties: {
      category:  { enum: ["coloring_book", "stationery", "bag", "combo"] },
      price:     { bsonType: "number", minimum: 1 },
      stock_qty: { bsonType: "number", minimum: 0 }       // same rule as CHECK (stock_qty >= 0)
    }
  } }
});

// ---------------------------------------------------------------- customers
db.createCollection("customers", {
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["_id", "full_name", "email", "phone", "country", "id_verification_status"],
    properties: {
      email: { bsonType: "string", pattern: "^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$" },
      id_verification_status: { enum: ["not_started", "pending", "verified", "failed"] },
      addresses: { bsonType: "array", maxItems: 10 }
    }
  } }
});

db.createCollection("books");

// ---------------------------------------------------------------- load data
// The documents are produced by tools/generate_data.js (the same seeded code
// writes data/*.json). In this portfolio they were inserted through Atlas
// Data Explorer's "Add data" -> "Insert document" (orders in three batches
// of about 500). With the command-line tools instead:
//   mongoimport --uri "<atlas-uri>/relaks" --collection orders --jsonArray --file data/orders.json
// (repeat for customers, products, books)

// ---------------------------------------------------------------- test the validator
// Expected: "Document failed validation" (no items, unknown channel, negative total).
db.orders.insertOne({
  _id: "RLX-ORD-TEST-BAD",
  customer: { customer_id: 2, name: "Tunde Bakare" },
  ship_to: { street: "7 Allen Avenue", zone: "Ikeja / Maryland", city: "Lagos" },
  sales_channel: "facebook",
  status: "paid",
  ordered_at: new Date(),
  items: [],
  order_total: -500,
  payments: []
});
