/*
 * Portfolio 4 - generate the Relaks MongoDB dataset (SIMULATED data only).
 *
 *   customers  200 (the 8 from Portfolio 1 + 192 generated); addresses and
 *              Reading Club subscriptions/loans EMBEDDED
 *   products   the 8 Relaks products (same SKUs and prices as Portfolio 1);
 *              combo contents EMBEDDED
 *   books      the 6 Reading Club books
 *   orders     1,507 (the 7 from Portfolio 1 + 1,500 generated); line items,
 *              delivery address, promo, payment attempts and delivery EMBEDDED,
 *              plus a snapshot of the customer
 *
 * Dates are MongoDB Extended JSON ({"$date": ...}). All names, emails, phones
 * and streets are fictional. The random generator is seeded, so the output is
 * identical every time.
 *
 * Node:     node generate_data.js        -> writes ../data/*.json
 * Browser:  the same code runs in Atlas Data Explorer's page to build the
 *           documents that were pasted into "Insert document".
 */
function buildRelaksData() {
  // ---------- seeded random numbers (mulberry32) ----------
  let seed = 8103;
  const rnd = () => {
    seed |= 0; seed = (seed + 0x6D2B79F5) | 0;
    let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const randint = (a, b) => a + Math.floor(rnd() * (b - a + 1));
  const choice = (arr) => arr[Math.floor(rnd() * arr.length)];
  const weighted = (arr, w) => {
    const total = w.reduce((s, x) => s + x, 0);
    let r = rnd() * total;
    for (let i = 0; i < arr.length; i++) { r -= w[i]; if (r < 0) return arr[i]; }
    return arr[arr.length - 1];
  };
  const sample = (arr, k) => {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(rnd() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
    return a.slice(0, k);
  };

  // ---------- dates: Lagos time (UTC+1) -> Extended JSON in UTC ----------
  const wat = (y, mo, d, h = 0, mi = 0) => new Date(Date.UTC(y, mo - 1, d, h - 1, mi));
  const ej = (dt) => ({ $date: dt.toISOString().replace(".000Z", "Z") });
  const d = (s) => {                                 // "2026-10-02 10:15"
    const [ymd, hm = "00:00"] = s.split(" ");
    const [y, mo, dd] = ymd.split("-").map(Number);
    const [h, mi] = hm.split(":").map(Number);
    return ej(wat(y, mo, dd, h, mi));
  };
  const addMin = (dt, m) => new Date(dt.getTime() + m * 60000);

  // ---------- reference data ----------
  const ZONES = { "Yaba / Surulere": 2000, "Ikeja / Maryland": 2500, "Lekki Phase 1 / VI": 3500,
                  "Ajah / Sangotedo": 4500, "Ikorodu": 5000 };
  const zoneNames = Object.keys(ZONES);
  const PROMOS = {
    BFFREEDEL: { code: "BFFREEDEL", discount_percent: 0, free_delivery: true },
    BF20: { code: "BF20", discount_percent: 20, free_delivery: false },
    BF40: { code: "BF40", discount_percent: 40, free_delivery: false } };

  // ---------- products (polymorphic: each category has its own attributes) ----------
  const book = (sku, ed, stock) => ({ _id: sku, name: `Relaks Coloring Book — ${ed} Edition`, category: "coloring_book",
    price: 10000, stock_qty: stock, is_active: true,
    attributes: { edition: ed, pages: 50, paper: "120gsm, single-sided" } });
  const products = [
    book("BOOK-PINK", "Pink", 120), book("BOOK-TEAL", "Teal", 95), book("BOOK-LAV", "Lavender", 3),
    { _id: "PENCIL-24", name: "24 Colored Pencils", category: "stationery", price: 4000, stock_qty: 200, is_active: true,
      attributes: { count: 24, type: "colored pencil" } },
    { _id: "FELT-24", name: "24 Felt Pens", category: "stationery", price: 5000, stock_qty: 150, is_active: true,
      attributes: { count: 24, type: "felt-tip pen", washable: true } },
    { _id: "TOTE-RLX", name: "Relaks Tote Bag", category: "bag", price: 8000, stock_qty: 60, is_active: true,
      attributes: { material: "canvas", colour: "cream" } },
    { _id: "COMBO-25K", name: "₦25k Combo (1 book + tote bag + pencils)", category: "combo", price: 25000,
      stock_qty: 40, is_active: true,
      components: [{ sku: "BOOK-PINK", qty: 1 }, { sku: "TOTE-RLX", qty: 1 }, { sku: "PENCIL-24", qty: 1 }] },
    { _id: "COMBO-32K", name: "₦32k Combo (2 books + pencils + felt pens)", category: "combo", price: 32000,
      stock_qty: 40, is_active: true,
      components: [{ sku: "BOOK-PINK", qty: 1 }, { sku: "BOOK-TEAL", qty: 1 }, { sku: "PENCIL-24", qty: 1 },
                   { sku: "FELT-24", qty: 1 }] } ];
  const PRODUCT = Object.fromEntries(products.map((p) => [p._id, p]));

  // ---------- Reading Club books ----------
  const books = [
    { _id: 1, title: "Things Fall Apart", author: "Chinua Achebe", genre: "Fiction", copies_total: 4 },
    { _id: 2, title: "Purple Hibiscus", author: "Chimamanda Ngozi Adichie", genre: "Fiction", copies_total: 3 },
    { _id: 3, title: "Atomic Habits", author: "James Clear", genre: "Self-help", copies_total: 5 },
    { _id: 4, title: "The Psychology of Money", author: "Morgan Housel", genre: "Finance", copies_total: 3 },
    { _id: 5, title: "Stay With Me", author: "Ayobami Adebayo", genre: "Fiction", copies_total: 2 },
    { _id: 6, title: "Born a Crime", author: "Trevor Noah", genre: "Memoir", copies_total: 2 } ];
  const BOOK = Object.fromEntries(books.map((b) => [b._id, b]));
  const loan = (id, delivered, due, returned = null) => ({ book_id: id, title: BOOK[id].title,
    delivered_on: d(delivered + " 12:00"), due_on: d(due + " 12:00"), returned_on: returned ? d(returned + " 12:00") : null });
  const PLANS = { Monthly: { plan: "Monthly", books_allowed: 2, price: 8000, delivery_fee: 6000 },
                  Quarterly: { plan: "Quarterly", books_allowed: 5, price: 22500, delivery_fee: 6000 } };

  // ---------- customers ----------
  const addr = (label, street, zone, isDefault) => ({ label, street, zone, city: "Lagos", is_default: isDefault });
  const customers = [
    { _id: 1, full_name: "Adaeze Okafor", email: "adaeze.okafor@example.com", phone: "08011110001", country: "Nigeria",
      id_verification_status: "verified",
      addresses: [addr("home", "12 Herbert Macaulay Way", "Yaba / Surulere", true),
                  addr("office", "4 Adeola Odeku Street", "Lekki Phase 1 / VI", false)],
      reading_club: { subscriptions: [
        { ...PLANS.Monthly, start_date: d("2026-10-01"), end_date: d("2026-10-31"), status: "expired", auto_renew: false,
          loans: [loan(1, "2026-10-02", "2026-10-31", "2026-10-30"), loan(3, "2026-10-02", "2026-10-31", "2026-10-30")] },
        { ...PLANS.Monthly, start_date: d("2026-11-01"), end_date: d("2026-12-01"), status: "active", auto_renew: true,
          loans: [loan(2, "2026-11-02", "2026-12-01"), loan(4, "2026-11-02", "2026-12-01")] } ] },
      created_at: d("2026-09-20 10:00") },
    { _id: 2, full_name: "Tunde Bakare", email: "tunde.bakare@example.com", phone: "08011110002", country: "Nigeria",
      id_verification_status: "not_started", addresses: [addr("home", "7 Allen Avenue", "Ikeja / Maryland", true)],
      created_at: d("2026-09-28 18:00") },
    { _id: 3, full_name: "Zainab Bello", email: "zainab.bello@example.com", phone: "08011110003", country: "Nigeria",
      id_verification_status: "verified", addresses: [addr("home", "21 Admiralty Way", "Lekki Phase 1 / VI", true)],
      reading_club: { subscriptions: [
        { ...PLANS.Quarterly, start_date: d("2026-09-15"), end_date: d("2026-12-14"), status: "active", auto_renew: false,
          loans: [1, 3, 5, 6, 4].map((b) => loan(b, "2026-09-16", "2026-12-14")) } ] },
      created_at: d("2026-09-10 12:00") },
    { _id: 4, full_name: "Chidi Nwosu", email: "chidi.nwosu@example.com", phone: "08011110004", country: "Nigeria",
      id_verification_status: "pending", addresses: [addr("home", "3 Abraham Adesanya Road", "Ajah / Sangotedo", true)],
      created_at: d("2026-10-11 09:00") },
    { _id: 5, full_name: "Funmi Adeyemi", email: "funmi.adeyemi@example.com", phone: "08011110005", country: "Nigeria",
      id_verification_status: "not_started", addresses: [addr("home", "15 Ebute Road", "Ikorodu", true)],
      created_at: d("2026-10-30 20:00") },
    // Wanjiru (Kenya) has not saved an address yet: an empty array, no NULL row needed.
    { _id: 6, full_name: "Wanjiru Kamau", email: "wanjiru.kamau@example.com", phone: "0700111006", country: "Kenya",
      id_verification_status: "not_started", addresses: [], created_at: d("2026-10-15 15:00") },
    { _id: 7, full_name: "Ifeoma Eze", email: "ifeoma.eze@example.com", phone: "08011110007", country: "Nigeria",
      id_verification_status: "verified", addresses: [addr("home", "9 Bode Thomas Street", "Yaba / Surulere", true)],
      reading_club: { subscriptions: [
        { ...PLANS.Monthly, start_date: d("2026-10-20"), end_date: d("2026-11-19"), status: "active", auto_renew: false,
          loans: [loan(3, "2026-10-21", "2026-11-19"), loan(5, "2026-10-21", "2026-11-19")] } ] },
      created_at: d("2026-10-18 08:00") },
    { _id: 8, full_name: "Kemi Lawal", email: "kemi.lawal@example.com", phone: "08011110008", country: "Nigeria",
      id_verification_status: "failed", addresses: [addr("home", "30 Opebi Road", "Ikeja / Maryland", true)],
      created_at: d("2026-10-25 14:00") } ];

  const FIRST = ["Adebayo", "Amaka", "Bisi", "Chinedu", "Damilola", "Emeka", "Folake", "Gbenga", "Halima", "Ibrahim",
    "Jumoke", "Kelechi", "Lola", "Musa", "Ngozi", "Obinna", "Oluwaseun", "Pelumi", "Rukayat", "Segun",
    "Temitope", "Uche", "Yetunde", "Zainab", "Aisha", "Bolaji", "Chioma", "Dayo", "Esther", "Femi"];
  const LAST = ["Adeleke", "Balogun", "Chukwu", "Danjuma", "Eze", "Fashola", "Gbadamosi", "Hassan", "Ibe", "Johnson",
    "Kalu", "Lawal", "Mohammed", "Nnamdi", "Ogunleye", "Okeke", "Olatunji", "Onyeka", "Salami", "Usman"];
  const STREETS = { "Yaba / Surulere": ["Herbert Macaulay Way", "Bode Thomas Street", "Adeniran Ogunsanya Street", "Ojuelegba Road"],
    "Ikeja / Maryland": ["Allen Avenue", "Opebi Road", "Toyin Street", "Isaac John Street"],
    "Lekki Phase 1 / VI": ["Admiralty Way", "Adeola Odeku Street", "Akin Adesola Street", "Awolowo Road"],
    "Ajah / Sangotedo": ["Lekki-Epe Expressway", "Abraham Adesanya Road", "Addo Road"],
    "Ikorodu": ["Ikorodu Road", "Ebute Road", "Lagos Road"] };

  // Copies still on the shelf after the hand-written loans: generated members
  // can only borrow what Relaks actually has.
  const onShelf = Object.fromEntries(books.map((b) => [b._id, b.copies_total]));
  for (const c of customers) for (const s of (c.reading_club?.subscriptions || []))
    for (const l of s.loans) if (l.returned_on === null) onShelf[l.book_id]--;

  for (let id = 9; id <= 200; id++) {
    const fn = choice(FIRST), ln = choice(LAST);
    const zone = weighted(zoneNames, [30, 25, 25, 12, 8]);
    const c = { _id: id, full_name: `${fn} ${ln}`, email: `${fn.toLowerCase()}.${ln.toLowerCase()}${id}@example.com`,
      phone: "0801111" + String(id).padStart(4, "0"), country: "Nigeria",
      id_verification_status: weighted(["not_started", "pending", "verified", "failed"], [70, 8, 20, 2]),
      addresses: [addr("home", `${randint(1, 120)} ${choice(STREETS[zone])}`, zone, true)],
      created_at: ej(addMin(wat(2026, 7, 1, 9), randint(0, 2400) * 60)) };
    if (rnd() < 0.15) {
      const oz = choice(zoneNames);
      c.addresses.push(addr("office", `${randint(1, 60)} ${choice(STREETS[oz])}`, oz, false));
    }
    const avail = Object.keys(onShelf).map(Number).filter((b) => onShelf[b] > 0);
    if (c.id_verification_status === "verified" && rnd() < 0.5 && avail.length >= 2) {
      const plan = choice(["Monthly", "Quarterly"]);
      const start = wat(2026, 10, randint(1, 28));
      const days = plan === "Monthly" ? 30 : 90;
      const picks = sample(avail, Math.min(plan === "Monthly" ? 2 : 3, avail.length));
      picks.forEach((b) => onShelf[b]--);
      c.reading_club = { subscriptions: [{ ...PLANS[plan], start_date: ej(start), end_date: ej(addMin(start, days * 1440)),
        status: "active", auto_renew: rnd() < 0.4,
        loans: picks.map((b) => ({ book_id: b, title: BOOK[b].title, delivered_on: ej(addMin(start, 1440)),
          due_on: ej(addMin(start, days * 1440)), returned_on: null })) }] };
    }
    customers.push(c);
  }
  const CUSTOMER = Object.fromEntries(customers.map((c) => [c._id, c]));

  // ---------- orders ----------
  const snapshot = (id) => ({ customer_id: id, name: CUSTOMER[id].full_name, phone: CUSTOMER[id].phone });
  const shipTo = (id, label = "home") => {
    const a = CUSTOMER[id].addresses.find((x) => x.label === label);
    return { street: a.street, zone: a.zone, city: a.city };
  };
  const line = (sku, qty) => ({ sku, name: PRODUCT[sku].name, qty, unit_price: PRODUCT[sku].price });
  const totals = (items, fee) => {
    const sub = items.reduce((s, i) => s + i.qty * i.unit_price, 0);
    return { items_subtotal: sub, delivery_fee: fee, order_total: sub + fee };
  };
  const pay = (ref, amount, status, at) => ({ paystack_reference: ref, amount, status, paid_at: at ? d(at) : null });
  const order = (id, cid, label, promo, channel, status, fee, at, items, payments, delivery) => {
    const o = { _id: id, customer: snapshot(cid), ship_to: shipTo(cid, label), sales_channel: channel, status,
      ordered_at: d(at), items, ...totals(items, fee), payments };
    if (promo) o.promo = PROMOS[promo];
    if (delivery) o.delivery = delivery;
    return o;
  };

  const orders = [
    order("RLX-ORD-000001", 1, "home", null, "website", "delivered", 2000, "2026-10-02 10:15",
      [line("BOOK-PINK", 1), line("PENCIL-24", 1)], [pay("RLX-PSK-0001", 16000, "success", "2026-10-02 10:16")],
      { rider: "Rider A", status: "delivered", dispatched_at: d("2026-10-03 09:00"), delivered_at: d("2026-10-03 13:20") }),
    order("RLX-ORD-000002", 2, "home", null, "instagram", "delivered", 2500, "2026-10-05 18:40",
      [line("COMBO-32K", 1)], [pay("RLX-PSK-0002", 34500, "success", "2026-10-05 18:41")],
      { rider: "Rider B", status: "delivered", dispatched_at: d("2026-10-06 10:00"), delivered_at: d("2026-10-06 15:45") }),
    order("RLX-ORD-000003", 3, "home", null, "whatsapp", "dispatched", 3500, "2026-10-20 12:05",
      [line("BOOK-TEAL", 2), line("FELT-24", 1)], [pay("RLX-PSK-0003", 28500, "success", "2026-10-20 12:06")],
      { rider: "Rider A", status: "in_transit", dispatched_at: d("2026-10-21 09:30") }),
    order("RLX-ORD-000004", 1, "office", "BFFREEDEL", "website", "paid", 0, "2026-11-07 09:30",
      [line("COMBO-25K", 1)], [pay("RLX-PSK-0004", 25000, "success", "2026-11-07 09:31")], { status: "awaiting" }),
    order("RLX-ORD-000005", 5, "home", "BFFREEDEL", "tiktok", "paid", 0, "2026-11-08 21:10",
      [line("BOOK-LAV", 1), line("BOOK-PINK", 1)], [pay("RLX-PSK-0005", 20000, "success", "2026-11-08 21:11")],
      { status: "awaiting" }),
    order("RLX-ORD-000006", 7, "home", null, "website", "pending", 2000, "2026-11-10 08:00",
      [line("BOOK-TEAL", 1)], [], null),
    order("RLX-ORD-000007", 8, "home", null, "x", "cancelled", 2500, "2026-10-28 14:22",
      [line("TOTE-RLX", 1)], [pay("RLX-PSK-0006", 10500, "failed", null)], null) ];

  const CHANNELS = ["website", "instagram", "whatsapp", "tiktok", "x"];
  const SKUS = Object.keys(PRODUCT);
  const start = wat(2026, 8, 1, 8), end = wat(2026, 11, 11, 22);
  const spanMin = Math.floor((end - start) / 60000);
  const times = Array.from({ length: 1500 }, () => addMin(start, randint(0, spanMin))).sort((a, b) => a - b);
  const bfStart = wat(2026, 11, 6), bfEnd = wat(2026, 11, 10);
  let ref = 6;
  times.forEach((at, i) => {
    const n = i + 8;
    let cid = randint(1, 200);
    if (CUSTOMER[cid].addresses.length === 0) cid = 1;
    const label = choice(CUSTOMER[cid].addresses.map((a) => a.label));
    const items = sample(SKUS, weighted([1, 2, 3], [60, 30, 10])).map((s) => line(s, weighted([1, 2], [85, 15])));
    let promo = null, fee = ZONES[shipTo(cid, label).zone];
    if (at >= bfStart && at < bfEnd && rnd() < 0.7) { promo = "BFFREEDEL"; fee = 0; }
    const ageDays = Math.floor((end - at) / 86400000);
    let status;
    if (rnd() < 0.05) status = "cancelled";
    else if (ageDays > 6) status = "delivered";
    else if (ageDays > 3) status = choice(["dispatched", "delivered"]);
    else if (ageDays > 0) status = choice(["paid", "dispatched"]);
    else status = choice(["pending", "paid"]);
    const total = totals(items, fee).order_total;
    const payments = [];
    const nextRef = () => "RLX-PSK-" + String(++ref).padStart(4, "0");
    if (status === "cancelled") payments.push({ paystack_reference: nextRef(), amount: total, status: "failed", paid_at: null });
    else if (status !== "pending") {
      if (rnd() < 0.08) payments.push({ paystack_reference: nextRef(), amount: total, status: "failed", paid_at: null });
      payments.push({ paystack_reference: nextRef(), amount: total, status: "success", paid_at: ej(addMin(at, randint(1, 5))) });
    }
    const o = { _id: "RLX-ORD-" + String(n).padStart(6, "0"), customer: snapshot(cid), ship_to: shipTo(cid, label),
      sales_channel: weighted(CHANNELS, [35, 30, 20, 10, 5]), status, ordered_at: ej(at), items, ...totals(items, fee), payments };
    if (promo) o.promo = PROMOS[promo];
    if (["paid", "dispatched", "delivered"].includes(status)) {
      let dl = { status: "awaiting" };
      if (status !== "paid") {
        const disp = addMin(at, randint(14, 30) * 60);
        dl = { rider: choice(["Rider A", "Rider B", "Rider C"]), status: "in_transit", dispatched_at: ej(disp) };
        if (status === "delivered") { dl.status = "delivered"; dl.delivered_at = ej(addMin(disp, randint(2, 8) * 60)); }
      }
      o.delivery = dl;
    }
    orders.push(o);
  });

  return { customers, products, books, orders };
}

if (typeof module !== "undefined" && require.main === module) {
  const fs = require("fs"), path = require("path");
  const out = path.join(__dirname, "..", "data");
  fs.mkdirSync(out, { recursive: true });
  for (const [name, docs] of Object.entries(buildRelaksData())) {
    fs.writeFileSync(path.join(out, name + ".json"), JSON.stringify(docs, null, 1));
    console.log(`${name}.json: ${docs.length} documents`);
  }
}
