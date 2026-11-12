// =====================================================================
// Portfolio 4 — 04_atomic_updates.js
// The "last Lavender copy" problem from Portfolio 3, in MongoDB.
//
// A write to ONE document is always atomic in MongoDB. So the stock check
// and the decrement go into a single conditional update: it only matches if
// a copy is still there. No lock, no read-then-write, no lost update.
//
// In this portfolio it was run in Atlas Data Explorer with "Bulk update
// documents" on the products collection: filter
// { _id: "BOOK-LAV", stock_qty: { $gte: 1 } }, update { $inc: { stock_qty: -1 } }.
// =====================================================================

use("relaks");

db.products.find({ _id: "BOOK-LAV" }, { stock_qty: 1 });          // 3 copies

// Run this 4 times (4 customers checking out at once):
db.products.updateOne(
  { _id: "BOOK-LAV", stock_qty: { $gte: 1 } },     // only if a copy is left
  { $inc: { stock_qty: -1 } }
);
// 1st, 2nd, 3rd: { matchedCount: 1, modifiedCount: 1 }
// 4th:           { matchedCount: 0, modifiedCount: 0 }  -> app shows "Sold out"

db.products.find({ _id: "BOOK-LAV" }, { stock_qty: 1 });          // 0, never -1

// Even WITHOUT the condition, the schema validator (minimum: 0) refuses to
// take the stock below zero, like CHECK (stock_qty >= 0) in Portfolio 1:
db.products.updateOne({ _id: "BOOK-LAV" }, { $inc: { stock_qty: -1 } });
// Expected: "Document failed validation"

// Put the stock back for the next demo:
db.products.updateOne({ _id: "BOOK-LAV" }, { $set: { stock_qty: 3 } });

// ---------------------------------------------------------------------
// Where the document model needs MORE than a single-document write:
// a checkout touches TWO collections (products: stock, orders: new order).
// MongoDB supports multi-document ACID transactions on a replica set (Atlas
// clusters are replica sets), but they must be started from a driver or
// mongosh session. Sketch of the checkout as a transaction:
//
// const s = db.getMongo().startSession();
// s.startTransaction({ readConcern: { level: "snapshot" }, writeConcern: { w: "majority" } });
// try {
//   const p = s.getDatabase("relaks").products;
//   const o = s.getDatabase("relaks").orders;
//   const r = p.updateOne({ _id: "BOOK-LAV", stock_qty: { $gte: 1 } }, { $inc: { stock_qty: -1 } });
//   if (r.modifiedCount !== 1) throw new Error("Sold out");
//   o.insertOne({ /* the new order document */ });
//   s.commitTransaction();
// } catch (e) { s.abortTransaction(); throw e; }
// finally { s.endSession(); }
//
// This is why the README recommends keeping stock + payments in PostgreSQL.
// ---------------------------------------------------------------------
