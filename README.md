# MIT 8103 — Advanced Database Systems Portfolio

**Student:** Akeju Tioluwani · Master of Information Technology, Miva Open University · First Semester 2026/2027

## Case study: Relaks

| | |
|---|---|
| **Organisation** | Relaks: a Lagos-based wellness brand selling adult coloring books, stationery and bundles, and running the Relaks Reading Club, a book-rental subscription. |
| **Nature of the business / system** | Multi-channel e-commerce (website, Instagram, WhatsApp, TikTok, X). It delivers within Lagos, uses city distributors in Kano, Abuja, Port Harcourt and Ibadan, and has customers in Nigeria, Kenya, the UK and South Africa. Payments go through Paystack. |
| **Users of the database** | Customers (shop, track orders, rent books), operations/admin staff (stock, dispatch, riders, promos), the finance team (revenue, payments, refunds), Reading Club partners (rental revenue and loans) |
| **Major data stored** | Customers and addresses, products and combos, stock levels, orders and line items, Paystack payments, deliveries and riders, promotions, rental plans, rental books, subscriptions and loans |
| **Key operations** | Add/update products, place orders, update stock, process payments and refunds, track delivery, apply Black Friday promos, start and renew rental subscriptions, record book loans and returns, report revenue by product, channel and zone |

All customer records in this repository are **simulated**. Product names, prices and plans follow the real Relaks catalogue.

## Portfolio activities

| # | Folder | Status |
|---|---|---|
| 1 | [`portfolio-1-database-design/`](portfolio-1-database-design/) | Done: ER diagram, schema, constraints, normalisation |
| 2 | [`portfolio-2-query-optimisation/`](portfolio-2-query-optimisation/) | Done: 300,000 simulated orders, execution plans before/after indexing, timing benchmark |
| 3 | [`portfolio-3-transactions-concurrency/`](portfolio-3-transactions-concurrency/) | Done: COMMIT/ROLLBACK/SAVEPOINT, lost update and `SELECT … FOR UPDATE`, isolation levels, deadlock |
| 4 | [`portfolio-4-nosql/`](portfolio-4-nosql/) | Done: MongoDB Atlas document model, validation, aggregation, indexes, suitability |
| 5 | [`portfolio-5-distributed-cloud/`](portfolio-5-distributed-cloud/) | Done: Atlas replica set, shard-key analysis, sharding simulation on 300,000 orders, consistency choices, cloud deployment |

## Tools

PostgreSQL 16+, psql / pgAdmin 4, MongoDB Atlas (Portfolios 4–5), Mermaid (ER diagram), Git and GitHub.

## AI use declaration

**Tool used:** Claude (Anthropic), used as a tutor and coding assistant between 10 and 14 November 2026.

**My own work:** I chose Relaks, my own business, as the case study and supplied its real business rules: products, prices, combos, delivery zones, Paystack payments and Reading Club plans. I signed up for MongoDB Atlas, ran the work on my own PostgreSQL 17 installation and Atlas cluster, and took every screenshot. I checked each result and corrected the design wherever it didn't match how Relaks actually operates. When a session froze in Portfolio 3, I worked out why and recorded it as a lesson. The reflection is my own.

**What I used Claude for:**
- Explaining concepts that were new to me: normal forms, execution plans, isolation levels, locks, replication and shard keys.
- Guiding me through setting up PostgreSQL and Atlas 

**How I verified the output:** Every script was run against my own databases. I checked results against the expected outcomes: all 11 constraint tests rejected, order totals matching Paystack amounts, the lost update reproduced and then fixed, 19 documents examined after indexing, and orders split 25% per shard. All customer data is simulated; no real Relaks data was given to the AI or stored in this repository.
