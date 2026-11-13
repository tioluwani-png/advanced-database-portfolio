// =====================================================================
// Portfolio 5 — 03_replication_and_consistency.js
// Replication, availability and consistency settings for the Relaks
// Atlas cluster (a 3-member replica set: 1 primary + 2 secondaries).
//
// These commands are for mongosh connected to the cluster. The replica set
// itself is shown in the Atlas screenshots; the free M0 tier hides some
// admin commands (rs.status()), so the outputs in comments describe what
// a dedicated cluster returns.
// =====================================================================

use("relaks");

// ---------------------------------------------------------------- who is primary?
db.hello();
// -> { isWritablePrimary: true, hosts: [ "...-00-00", "...-00-01", "...-00-02" ],
//      primary: "...-00-01:27017", setName: "atlas-...-shard-0", ... }
// Every write goes to the primary; the two secondaries copy its oplog
// (operation log) and replay it. If the primary fails, the secondaries hold
// an ELECTION and one becomes primary, usually within seconds. Drivers
// retry the write automatically (retryWrites=true in the Atlas URI).

// ---------------------------------------------------------------- consistency per operation

// 1. Money: a payment must survive the loss of the primary.
//    w: "majority" = acknowledged only after 2 of the 3 members have it,
//    so a failover can never roll it back. (The default since MongoDB 5.0.)
db.orders.updateOne(
  { _id: "RLX-ORD-000006" },
  { $set: { status: "paid" },
    $push: { payments: { paystack_reference: "RLX-PSK-DEMO", amount: 12000, status: "success", paid_at: new Date() } } },
  { writeConcern: { w: "majority", wtimeout: 5000 } }
);

// 2. Checkout stock check: must see the latest committed value -> read the
//    primary with readConcern "majority" (no reading data that might be rolled back).
db.products.find({ _id: "BOOK-LAV" }).readPref("primary").readConcern("majority");

// 3. Catalogue page / reports: slightly old data is fine -> read from a
//    secondary to take load off the primary (eventual consistency).
db.products.find({ is_active: true }).readPref("secondaryPreferred");
db.orders.aggregate([{ $group: { _id: "$sales_channel", revenue: { $sum: "$order_total" } } }],
                    { readPreference: "secondary" });

// 4. Bounded staleness: never read from a secondary more than 90 s behind.
//    (Driver option in the connection string.)
//    mongodb+srv://.../relaks?readPreference=secondaryPreferred&maxStalenessSeconds=90

// ---------------------------------------------------------------- read-your-own-writes
// A customer who has just paid must see "paid" on the next page, even if
// that read goes to a secondary: a causally consistent session guarantees it.
const s = db.getMongo().startSession({ causalConsistency: true });
const o = s.getDatabase("relaks").orders;
o.updateOne({ _id: "RLX-ORD-000006" }, { $set: { status: "paid" } }, { writeConcern: { w: "majority" } });
o.find({ _id: "RLX-ORD-000006" }).readPref("secondary");   // guaranteed to see "paid"
s.endSession();
