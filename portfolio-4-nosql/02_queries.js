// =====================================================================
// Portfolio 4 — 02_queries.js
// The questions Relaks actually asks, answered against the document model.
// Each query can be pasted into mongosh. For this portfolio they were run in
// Atlas Data Explorer (Find: filter / project / sort boxes; Aggregations:
// text mode). Q1, Q5 and Q7 are in the screenshots.
// =====================================================================

use("relaks");

// ---------------------------------------------------------------- Q1
// Customer profile page: ONE read returns the customer, all saved addresses
// and their whole Reading Club history (plans, loans, due dates).
// In PostgreSQL this needed customer + address + rental_subscription +
// rental_plan + rental_loan + rental_book: 5 joins.
db.customers.find({ _id: 7 });          // Ifeoma Eze (screenshot 03)

// ---------------------------------------------------------------- Q2
// A customer's order history, newest first (the "My orders" page).
db.orders.find(
  { "customer.customer_id": 1 },
  { ordered_at: 1, status: 1, order_total: 1, "items.name": 1, "items.qty": 1 }
).sort({ ordered_at: -1 });

// ---------------------------------------------------------------- Q3
// Orders where the first card was declined but the customer retried and paid.
// Querying INSIDE an embedded array: needs no join to a payment table.
db.orders.find(
  { "payments.status": "failed", status: { $ne: "cancelled" } },
  { "customer.name": 1, order_total: 1, "payments.status": 1, "payments.paystack_reference": 1 }
);

// ---------------------------------------------------------------- Q4
// Low-stock alert for the Black Friday finale.
db.products.find({ stock_qty: { $lt: 10 } }, { name: 1, stock_qty: 1 });

// ---------------------------------------------------------------- Q5 (aggregation)
// Revenue and units by product, for orders that were actually paid.
db.orders.aggregate([
  { $match: { status: { $in: ["paid", "dispatched", "delivered"] } } },
  { $unwind: "$items" },
  { $group: {
      _id: "$items.sku",
      units_sold: { $sum: "$items.qty" },
      revenue: { $sum: { $multiply: ["$items.qty", "$items.unit_price"] } } } },
  { $sort: { revenue: -1 } }
]);

// ---------------------------------------------------------------- Q6 (aggregation)
// Sales by month and channel (Lagos time), to see where Relaks sells best.
db.orders.aggregate([
  { $match: { status: { $in: ["paid", "dispatched", "delivered"] } } },
  { $group: {
      _id: { month: { $dateToString: { format: "%Y-%m", date: "$ordered_at", timezone: "Africa/Lagos" } },
             channel: "$sales_channel" },
      orders: { $sum: 1 },
      revenue: { $sum: "$order_total" } } },
  { $sort: { "_id.month": 1, revenue: -1 } }
]);

// ---------------------------------------------------------------- Q7 (aggregation + $lookup)
// Reading Club: how many copies of each book are out on loan right now, and
// how many are still available. Loans are embedded in customers; the book
// catalogue is its own collection, so this uses $lookup (MongoDB's join).
db.customers.aggregate([
  { $unwind: "$reading_club.subscriptions" },
  { $match: { "reading_club.subscriptions.status": "active" } },
  { $unwind: "$reading_club.subscriptions.loans" },
  { $match: { "reading_club.subscriptions.loans.returned_on": null } },
  { $group: { _id: "$reading_club.subscriptions.loans.book_id", on_loan: { $sum: 1 } } },
  { $lookup: { from: "books", localField: "_id", foreignField: "_id", as: "book" } },
  { $unwind: "$book" },
  { $project: { _id: 0, title: "$book.title", copies_total: "$book.copies_total", on_loan: 1,
                available: { $subtract: ["$book.copies_total", "$on_loan"] } } },
  { $sort: { title: 1 } }
]);
// A negative "available" figure would mean more copies are lent out than
// Relaks owns: MongoDB cannot stop that with a foreign key or CHECK across
// collections, so the application has to (see README, suitability).

// ---------------------------------------------------------------- Q8 (aggregation)
// Black Friday week 1 (free delivery, 6–9 Nov): daily orders and how many used the code.
db.orders.aggregate([
  { $match: { ordered_at: { $gte: ISODate("2026-11-01T00:00:00+01:00") }, status: { $ne: "cancelled" } } },
  { $group: {
      _id: { $dateToString: { format: "%Y-%m-%d", date: "$ordered_at", timezone: "Africa/Lagos" } },
      orders: { $sum: 1 },
      used_BFFREEDEL: { $sum: { $cond: [{ $eq: ["$promo.code", "BFFREEDEL"] }, 1, 0] } },
      revenue: { $sum: "$order_total" } } },
  { $sort: { _id: 1 } }
]);
