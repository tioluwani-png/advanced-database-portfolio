// =====================================================================
// Portfolio 5 — 02_shard_key_analysis.js
// Choosing a shard key for relaks.orders, using the real data in Atlas.
//
// A good shard key has HIGH cardinality (many distinct values), spreads
// documents EVENLY, does NOT always increase (or every new write hits the
// same shard), and appears in the most frequent queries (so they can go to
// one shard). This pipeline measures the three candidates side by side.
// Run in Atlas Data Explorer: relaks.orders -> Aggregations -> text mode.
// =====================================================================

use("relaks");

db.orders.aggregate([
  { $facet: {
      // Candidate A: delivery zone. Only 5 values, and Lekki/Yaba/Ikeja dominate.
      by_zone: [
        { $group: { _id: "$ship_to.zone", orders: { $sum: 1 } } },
        { $sort: { orders: -1 } } ],

      // Candidate B: order month. Always increasing: every new order goes to
      // the newest range, so one shard takes all the writes.
      by_month: [
        { $group: { _id: { $dateToString: { format: "%Y-%m", date: "$ordered_at", timezone: "Africa/Lagos" } },
                    orders: { $sum: 1 } } },
        { $sort: { _id: 1 } } ],

      // Candidate C: customer_id spread over 4 shards. customer_id mod 4 is
      // used here as a simple stand-in for MongoDB's hashed shard key.
      by_customer_hash_4_shards: [
        { $group: { _id: { $mod: ["$customer.customer_id", 4] }, orders: { $sum: 1 } } },
        { $sort: { _id: 1 } } ]
  } },
  // One readable line per value ("Lekki Phase 1 / VI  →  420 orders").
  { $project: {
      A_by_zone: { $map: { input: "$by_zone", as: "x",
        in: { $concat: [ { $toString: "$$x._id" }, "  →  ", { $toString: "$$x.orders" }, " orders" ] } } },
      B_by_month: { $map: { input: "$by_month", as: "x",
        in: { $concat: [ { $toString: "$$x._id" }, "  →  ", { $toString: "$$x.orders" }, " orders" ] } } },
      C_by_customer_hash_4_shards: { $map: { input: "$by_customer_hash_4_shards", as: "x",
        in: { $concat: [ { $toString: "$$x._id" }, "  →  ", { $toString: "$$x.orders" }, " orders" ] } } }
  } }
]);
// Result (1,507 orders):
//   A by zone:     Lekki 420, Yaba 400, Ikeja 372, Ajah 182, Ikorodu 133
//   B by month:    2026-08 452, 2026-09 450, 2026-10 443, 2026-11 162 (and growing)
//   C by customer: 361 / 404 / 375 / 367

// ---------------------------------------------------------------------
// The decision (design only: the free M0 tier cannot be sharded; sharding
// needs a dedicated M30+ cluster):
//
//   sh.enableSharding("relaks");
//   sh.shardCollection("relaks.orders", { "customer.customer_id": "hashed" });
//
// - "My orders" (the most frequent query) includes customer.customer_id,
//   so it is routed to ONE shard by mongos.
// - Finance reports by date go to ALL shards (scatter-gather) — acceptable,
//   because they run rarely and can read from secondaries.
// - The unique Paystack-reference index from Portfolio 4 would have to
//   include the shard key, or move to a separate payments collection
//   sharded by paystack_reference (see README).
// ---------------------------------------------------------------------
