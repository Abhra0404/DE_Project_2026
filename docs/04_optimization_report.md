# Phase 4: Optimization Report

## 1. Method

The baseline was measured without Phase 4 indexes using three runs per query.
The optimized workload was measured after applying
[`sql/05_indexes.sql`](../sql/05_indexes.sql), running `ANALYZE`, and executing
[`sql/06_optimized_queries.sql`](../sql/06_optimized_queries.sql) five times:

```bash
./benchmarks/run_benchmark.sh DE_Project optimized 5 sql/06_optimized_queries.sql
```

The optimized raw plans are in
[`benchmarks/results/optimized/`](../benchmarks/results/optimized/), and the
summary is in
[`benchmarks/results/optimized/summary.csv`](../benchmarks/results/optimized/summary.csv).

The workload returned all queries successfully. Write queries continued to
run inside `BEGIN`/`ROLLBACK`.

## 2. Before/after results

Improvement is calculated as:

```text
(before_ms - after_ms) / before_ms * 100
```

Negative improvement means the optimized version was slower.

| Query | Before (ms) | Problem found | Optimization applied | After (ms) | Improvement | Same result? |
|---|---:|---|---|---:|---:|:---:|
| R01 | 0.458 | Locality/status filter scanned small tables | Locality/status/rating index | 0.188 | 59.0% | Yes |
| R02 | 9.948 | Leading-wildcard dish search and joins | Menu/restaurant/locality indexes; text predicate remains | 2.956 | 70.3% | Yes |
| R03 | 1.745 | Menu scan for one restaurant | Covering menu index | 0.106 | 93.9% | Yes |
| R04 | 5.085 | Customer orders scanned and sorted | `(customer_id, placed_at DESC)` index | 0.299 | 94.1% | Yes |
| R05 | 6.820 | `PREPARING` orders scanned | Partial index on `accepted_at` | 0.025 | 99.6% | Yes |
| R06 | 4.690 | `DATE(placed_at)` prevented a direct date-range lookup | Timestamp range rewrite and restaurant/date index | 0.042 | 99.1% | Yes |
| R07 | 5.544 | Restaurant delivery history scanned | Partial delivered restaurant/date index | 0.286 | 94.8% | Yes |
| R08 | 6.856 | Delivered orders and ranking required broad joins | Delivered restaurant/date index | 3.514 | 48.7% | Yes |
| R09 | 23.266 | Year extracted from every timestamp | Timestamp range rewrite and order-date index | 23.370 | -0.4% | Yes |
| R10 | 5.169 | Delivery duration calculation scanned orders | Covering placed-time index | 0.936 | 81.9% | Yes |
| R11 | 5.193 | Partner delivery history scanned | Partial partner/delivery-date index | 0.087 | 98.3% | Yes |
| R12 | 7.585 | Unassigned orders scanned and sorted | Partial unassigned/placed-time index | 0.025 | 99.7% | Yes |
| R13 | 5.576 | `NOT IN` was NULL-sensitive and scanned orders | `NOT EXISTS` plus placed-time index | 0.433 | 92.2% | Corrected |
| R14 | 7.595 | Gold and June-order filters scanned tables | Gold-expiry and customer-order indexes | 1.450 | 80.9% | Yes |
| R15 | 13.284 | Delivered coupon orders aggregated broadly | Partial delivered coupon index | 8.003 | 39.8% | Yes |
| R16 | 6.762 | Failed payments scanned by status/date | Payment status/date covering index | 0.191 | 97.2% | Yes |
| R17 | 14.641 | Failed payments and orders grouped after scans | Partial failed-payment order index | 10.981 | 25.0% | Yes |
| R18 | 7.463 | Leading-wildcard review search remained unindexed | No query rewrite; text search needs trigram/full-text design | 7.354 | 1.5% | Yes |
| R19 | 4355.064 | Three correlated subqueries repeatedly scanned orders/reviews | Pre-aggregated order/review CTEs and joins | 22.751 | 99.5% | Yes |
| R20 | 22.189 | Mumbai customer spend grouped after order scan | Customer-city and delivered customer-order indexes | 18.496 | 16.6% | Yes |
| R21 | 10.726 | May orders grouped after a broad scan | Placed-time covering index | 4.689 | 56.3% | Yes |
| R22 | 14.914 | Eight-week city heatmap scanned orders | Restaurant/date and placed-time indexes | 3.835 | 74.3% | Yes |
| R23 | 39.141 | Large `OFFSET` pagination processed 100,000 rows | Covering descending placed-time index | 6.593 | 83.2% | Yes |
| R24 | 5.624 | Successful payments were scanned | Partial successful-payment order index | 0.262 | 95.3% | Yes |
| R25 | 0.346 | Small restaurant/locality tables were scanned | Locality/status and cuisine-array indexes | 0.280 | 19.1% | Yes |
| W01 | 0.967 | Single-row insert; index maintenance adds small overhead | All Phase 4 indexes | 1.075 | -11.2% | Yes |
| W02 | 8.721 | Oldest eligible order was scanned | Partial unassigned/placed-time index | 0.555 | 93.6% | Yes |
| W03 | 1.760 | Dessert rows were found by table scan | Restaurant/category menu index | 0.253 | 85.6% | Yes |
| W04 | 21.617 | All reviews still need to be aggregated | Restaurant review index; aggregation remains necessary | 24.804 | -14.7% | Yes |
| W05 | 27.560 | Gold customers were scanned | Partial Gold-expiry index | 17.545 | 36.3% | Yes |
| **Total** | **4646.309** |  |  | **161.384** | **96.5%** |  |

The total is the sum of the individual query averages, not the elapsed time
of one combined transaction.

## 3. Largest improvements

### R19: restaurant health report

The original query ran three correlated subqueries for every Bengaluru
restaurant. The optimized query calculates order statistics and review
statistics once in two CTEs, then joins those results to the restaurants.

- Before: approximately 4.36 seconds; sequential scans of orders and reviews
  were repeated.
- After: 22.751 ms; the aggregated CTEs are evaluated once.
- This was the largest improvement and is primarily a query rewrite rather
  than an index-only improvement.

### R12: unassigned dispatch queue

The partial index contains only rows with no partner and status `PLACED` or
`ACCEPTED`, already ordered by `placed_at`. This directly supports the
oldest-first `LIMIT 50` request.

### R05: kitchen-delay alert

The partial `PREPARING` index narrows the scan to relevant orders and orders
the entries by `accepted_at`, matching both the filter and the output order.

### R06: restaurant date filter

The original `DATE(placed_at)` expression applied a function to the column.
The optimized version uses an inclusive/exclusive `timestamptz` range, so the
restaurant/date index can be used directly.

### R11: partner earnings

The partial delivered-order index starts with `partner_id` and then
`placed_at`, matching the equality and date predicates used by the query.

Before/after raw plans for these queries are available in the corresponding
files under [`benchmarks/results/`](../benchmarks/results/).

### Plan evidence for the five largest improvements

| Query | Before plan scan | After plan scan | Raw plans |
|---|---|---|---|
| R12 | `Seq Scan on orders` | `Index Scan using idx_orders_unassigned_placed` | [`baseline/R12.txt`](../benchmarks/results/baseline/R12.txt), [`optimized/R12.txt`](../benchmarks/results/optimized/R12.txt) |
| R05 | `Seq Scan on orders` | `Index Scan using idx_orders_preparing_accepted` | [`baseline/R05.txt`](../benchmarks/results/baseline/R05.txt), [`optimized/R05.txt`](../benchmarks/results/optimized/R05.txt) |
| R19 | Repeated `Seq Scan` on orders and reviews | One-time aggregated scans of orders and reviews | [`baseline/R19.txt`](../benchmarks/results/baseline/R19.txt), [`optimized/R19.txt`](../benchmarks/results/optimized/R19.txt) |
| R06 | `Seq Scan on orders` | `Index Scan using idx_orders_restaurant_placed` | [`baseline/R06.txt`](../benchmarks/results/baseline/R06.txt), [`optimized/R06.txt`](../benchmarks/results/optimized/R06.txt) |
| R11 | `Seq Scan on orders` | `Index Scan using idx_orders_partner_delivered_placed` | [`baseline/R11.txt`](../benchmarks/results/baseline/R11.txt), [`optimized/R11.txt`](../benchmarks/results/optimized/R11.txt) |

## 4. Result correctness

Indexes do not change query results. For the rewritten queries, both
directions of `EXCEPT` were checked:

- R06 differences: **0 rows**
- R09 differences: **0 rows**
- R19 differences: **0 rows**

R13 intentionally changes the result because the original query is incorrect
when its `NOT IN` subquery contains `NULL` partner IDs. The original returned
**0** active Bengaluru partners, while the corrected `NOT EXISTS` query
returned **129** partners with no assignment since 25 June 2026. `NOT EXISTS`
compares the partner ID directly and is the correct business result.

## 5. Write overhead

| Write query | Before (ms) | After (ms) | Change |
|---|---:|---:|---:|
| W01 | 0.967 | 1.075 | 11.2% slower |
| W02 | 8.721 | 0.555 | 93.6% faster |
| W03 | 1.760 | 0.253 | 85.6% faster |
| W04 | 21.617 | 24.804 | 14.7% slower |
| W05 | 27.560 | 17.545 | 36.3% faster |

W01 is a single-row insert and pays a small index-maintenance cost. W04
still aggregates all reviews, and maintaining the review index adds overhead
to the update. These costs are acceptable because the indexed read workload
contains frequent customer, dispatch, payment, and reporting queries.

## 6. Index storage

The following sizes were measured with `pg_relation_size` after loading the
seed data and creating the Phase 4 indexes:

| Index | Size | Table size |
|---|---:|---:|
| `idx_customers_city` | 568 kB | 2600 kB |
| `idx_customers_gold_expiry` | 56 kB | 2600 kB |
| `idx_localities_city` | 16 kB | 8192 bytes |
| `idx_menu_items_restaurant_available_category` | 2432 kB | 3648 kB |
| `idx_menu_items_restaurant_category` | 848 kB | 3648 kB |
| `idx_orders_coupon_delivered` | 904 kB | 18 MB |
| `idx_orders_customer_placed` | 4640 kB | 18 MB |
| `idx_orders_partner_delivered_placed` | 4040 kB | 18 MB |
| `idx_orders_placed_covering` | 8840 kB | 18 MB |
| `idx_orders_preparing_accepted` | 16 kB | 18 MB |
| `idx_orders_restaurant_delivered_placed` | 4040 kB | 18 MB |
| `idx_orders_restaurant_placed` | 4640 kB | 18 MB |
| `idx_orders_unassigned_placed` | 16 kB | 18 MB |
| `idx_payments_failed_order` | 176 kB | 9280 kB |
| `idx_payments_status_attempted` | 5480 kB | 9280 kB |
| `idx_payments_success_order` | 2856 kB | 9280 kB |
| `idx_restaurants_cuisines_gin` | 600 kB | 376 kB |
| `idx_restaurants_locality_status_rating` | 664 kB | 376 kB |
| `idx_reviews_restaurant` | 880 kB | 2728 kB |

The covering orders index is the largest custom index because it stores
included columns for pagination and time-window queries. Partial indexes are
small because they contain only rows matching their business condition.

## 7. Queries not significantly improved

- **R09** remains approximately the same because it must aggregate delivery
  times across a large portion of the 2026 orders. The timestamp rewrite makes
  the predicate indexable, but most qualifying rows still need to be read.
- **R18** remains approximately the same because `%cold%` and `%late%`
  leading-wildcard searches need a trigram or full-text index, not a normal
  B-tree index. Adding that extension/index should be evaluated separately
  against its storage and write cost.
- **W04** remains slightly slower because recomputing every restaurant's
  rating necessarily reads and aggregates all review rows.
