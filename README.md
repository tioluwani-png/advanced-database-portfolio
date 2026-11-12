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
| 5 | [`portfolio-5-distributed-cloud/`](portfolio-5-distributed-cloud/) | In progress |

## Tools

PostgreSQL 16+, psql / pgAdmin 4, MongoDB Atlas (Portfolios 4–5), Mermaid (ER diagram), Git and GitHub.

## AI use declaration

**Tool used:** Claude (Anthropic), used as a coding and tutoring assistant throughout this portfolio.

**What I used it for:**
- Talking through which case study to use. I chose Relaks, my own business, because I know its real processes: multi-channel orders, Lagos delivery zones, Paystack payments, Black Friday promos and the Reading Club rentals.
- Drafting the SQL scripts (schema, sample data, constraint tests), the Mermaid ER diagram source and the first drafts of the README documentation, based on the Relaks details I gave it.
- Explaining concepts I was less sure of, such as partial unique indexes, why a price is copied into `order_item`, and how to show 2NF and 3NF step by step..
**How I reviewed, tested and verified the output:**
- I ran every script myself on PostgreSQL 17 on my own laptop. The screenshots in each portfolio folder come from those runs.
- I checked the results against what should happen. All 11 constraint tests are rejected, stock and customer counts are unchanged afterwards, and each order total in `order_summary` matches its Paystack payment amount.
- I checked the business rules against how Relaks actually operates (product range, prices, combos, delivery fees, rental plans) and corrected them where needed.
- I read through each design decision until I could explain it in my own words. The design choices, trade-offs and lessons are written up in my individual reflection.
- All customer data is simulated. No real Relaks customer data was given to the AI tool or stored in this repository.
