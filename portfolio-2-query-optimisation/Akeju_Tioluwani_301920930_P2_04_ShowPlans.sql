-- =====================================================================
-- Portfolio 2 — Akeju_Tioluwani_301920930_P2_04_ShowPlans.sql
-- Shows the saved EXPLAIN ANALYZE plans from Akeju_Tioluwani_301920930_P2_03_Benchmark.sql.
-- Run ONE of the queries below at a time (highlight it, then F5).
-- Buffer and parallel-worker detail lines are hidden for readability;
-- remove those two NOT LIKE filters to see the full plans.
-- =====================================================================

-- A) Q3 dispatch queue: Seq Scan + Sort  ->  Index Scan on the partial index
--    (screenshots/Akeju_Tioluwani_301920930_P2_03_PlanQ3.png)
SELECT phase, plan_line
FROM perf.plan
WHERE qid = 'Q3'
  AND plan_line NOT LIKE '%Buffers%' AND plan_line NOT LIKE '%Worker%'
ORDER BY phase DESC, line_no;

-- B) Q5: same question, two ways of writing it (both AFTER indexing)
--    Q5a (ordered_at::date = ...) cannot use ix_order_date -> Seq Scan
--    Q5b (range on ordered_at)    uses ix_order_date        -> Index Scan
--    (screenshots/Akeju_Tioluwani_301920930_P2_04_PlanQ5.png)
SELECT qid, plan_line
FROM perf.plan
WHERE qid IN ('Q5a', 'Q5b') AND phase = 'after'
  AND plan_line NOT LIKE '%Buffers%' AND plan_line NOT LIKE '%Worker%'
ORDER BY qid, line_no;

-- C) Any query: change the qid ('Q1' ... 'Q6')
SELECT phase, plan_line
FROM perf.plan
WHERE qid = 'Q1'
ORDER BY phase DESC, line_no;

-- D) Index sizes: partial indexes are tiny compared with full ones
SELECT indexrelname AS index_name,
       pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE schemaname = 'relaks' AND indexrelname LIKE 'ix_%'
ORDER BY pg_relation_size(indexrelid) DESC;
