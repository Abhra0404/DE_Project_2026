# Phase 3: Baseline Timings

## Method

The original workload was run without tuning indexes using:

```bash
./benchmarks/run_benchmark.sh DE_Project baseline
```

The benchmark uses `EXPLAIN (ANALYZE, BUFFERS)` and runs each query three
times. Write queries run inside `BEGIN`/`ROLLBACK`, so they do not permanently
modify the database. The raw plans are stored in
[`benchmarks/results/baseline/`](../benchmarks/results/baseline/), and the
generated summary is
[`summary.csv`](../benchmarks/results/baseline/summary.csv).

## Timing results

Times are execution times in milliseconds. Scan types are taken from the last
run's plan.

| Query | Type | Run 1 | Run 2 | Run 3 | Average | Scan type | Baseline observation |
|---|---|---:|---:|---:|---:|---|---|
| R01: Home feed: open restaurants in Koramangala, best rated first | READ | 0.783 | 0.304 | 0.288 | 0.458 | Seq Scan: restaurants, localities | Small tables make the full scans inexpensive. |
| R02: Dish search: available “paneer” dishes in Bengaluru | READ | 10.477 | 9.936 | 9.430 | 9.948 | Seq Scan: menu_items, restaurants, localities | Leading-wildcard text search scans the menu. |
| R03: Restaurant page: menu of restaurant 217 | READ | 1.859 | 1.684 | 1.691 | 1.745 | Seq Scan: menu_items | The menu table is scanned to find one restaurant's items. |
| R04: Customer's last 10 orders with restaurant names | READ | 6.395 | 4.381 | 4.478 | 5.085 | Seq Scan: orders; Index Scan: restaurants | Orders are filtered by customer without a supporting index. |
| R05: Orders stuck in `PREPARING` for over 40 minutes | READ | 8.169 | 6.218 | 6.074 | 6.820 | Seq Scan: orders | Status and timestamp predicates scan the orders table. |
| R06: Restaurant 217 orders on 15 June 2026 | READ | 4.656 | 4.742 | 4.673 | 4.690 | Seq Scan: orders | Restaurant and date filters have no useful index. |
| R07: Units sold per dish in May 2026 | READ | 5.763 | 5.777 | 5.093 | 5.544 | Seq Scan: orders; Index Scan: order_items, menu_items | Orders are scanned before indexed joins to detail tables. |
| R08: Top 3 dishes for Pune restaurants | READ | 7.799 | 6.343 | 6.427 | 6.856 | Seq Scan: orders, restaurants, localities; Index Scan: order_items | Aggregation and ranking process many joined rows. |
| R09: Average delivery time by city and month | READ | 23.468 | 23.321 | 23.009 | 23.266 | Seq Scan: orders, restaurants, localities | Date extraction and aggregation require a broad scan. |
| R10: June deliveries taking over 60 minutes | READ | 4.868 | 5.117 | 5.521 | 5.169 | Seq Scan: orders | Duration and date predicates scan orders. |
| R11: Partner 150's weekly earnings | READ | 5.344 | 5.189 | 5.047 | 5.193 | Seq Scan: orders | Partner, status, and date filters have no index. |
| R12: Oldest orders waiting for a partner | READ | 7.659 | 7.937 | 7.160 | 7.585 | Seq Scan: orders | Null partner/status filtering and ordering scan orders. |
| R13: Active Bengaluru partners without recent assignments | READ | 5.867 | 5.484 | 5.378 | 5.576 | Seq Scan: delivery_partners, orders | The `NOT IN` subquery scans orders. |
| R14: Gold members expiring before July 2026 who ordered in June | READ | 9.268 | 6.677 | 6.839 | 7.595 | Seq Scan: orders, customers | Membership and existence checks scan both tables. |
| R15: Coupon effectiveness | READ | 13.286 | 13.292 | 13.274 | 13.284 | Seq Scan: orders, coupons | Aggregation reads all orders and coupons. |
| R16: Failed payment attempts in the last 7 days | READ | 12.724 | 3.569 | 3.994 | 6.762 | Seq Scan: payments | Payment status and time are not indexed. |
| R17: Customers with at least two failed attempts | READ | 14.988 | 14.315 | 14.619 | 14.641 | Seq Scan: orders, payments | All payment failures and their order joins are grouped. |
| R18: Reviews mentioning cold food or late delivery | READ | 7.981 | 7.487 | 6.920 | 7.463 | Seq Scan: reviews | Leading-wildcard text predicates require a review scan. |
| R19: Bengaluru restaurant health report | READ | 4318.305 | 4334.108 | 4412.778 | 4355.064 | Seq Scan: restaurants, localities, orders, reviews | Correlated subqueries repeatedly scan orders and reviews; this is the clear outlier. |
| R20: Top 20 Mumbai customers by delivered spend | READ | 22.074 | 20.792 | 23.701 | 22.189 | Seq Scan: orders, customers | Customer/city filtering and aggregation scan orders. |
| R21: Repeat-customer share by city | READ | 11.251 | 10.713 | 10.214 | 10.726 | Seq Scan: customers, orders | The monthly grouping scans orders and joins customers. |
| R22: Bengaluru weekday/hour order heatmap | READ | 14.632 | 13.942 | 16.168 | 14.914 | Seq Scan: orders, restaurants, localities | Time extraction and city filtering scan recent orders. |
| R23: All orders, page 4,001 | READ | 37.502 | 41.102 | 38.819 | 39.141 | Seq Scan: orders | Large `OFFSET` pagination requires scanning and sorting many rows. |
| R24: Bill page for one order | READ | 5.607 | 5.389 | 5.875 | 5.624 | Index Scan: orders, restaurants, order_items, menu_items; Seq Scan: payments | Primary-key joins are indexed, but successful payments are scanned. |
| R25: Open Chinese restaurants in Pune | READ | 0.315 | 0.342 | 0.381 | 0.346 | Seq Scan: restaurants, localities | Small restaurant/locality tables make the scans inexpensive. |
| W01: Insert a new order header | WRITE | 1.666 | 0.605 | 0.630 | 0.967 | No scan | The insert mostly checks keys and writes one row. |
| W02: Assign partner 150 to oldest accepted order | WRITE | 9.642 | 8.193 | 8.327 | 8.721 | Seq Scan: orders; Index Scan: orders | Finding the oldest eligible order requires scanning orders. |
| W03: Hide desserts for restaurant 217 | WRITE | 1.752 | 1.600 | 1.927 | 1.760 | Seq Scan: menu_items | The update searches menu items without a tuning index. |
| W04: Recompute restaurant ratings | WRITE | 19.321 | 19.662 | 25.869 | 21.617 | Seq Scan: restaurants, reviews | All reviews are aggregated before updating restaurants. |
| W05: End expired Gold memberships | WRITE | 52.494 | 15.067 | 15.118 | 27.560 | Seq Scan: customers | The membership update scans all customers. |
| **Total (sum of averages)** |  |  |  |  | **4646.309** |  |  |

## Baseline observations

- The largest baseline cost is **R19**, at **4355.064 ms** on average. Its
  correlated subqueries repeatedly read orders and reviews for each Bengaluru
  restaurant.
- **R23** is the next notable read cost because `OFFSET 100000` requires
  PostgreSQL to process a large number of earlier rows.
- Most smaller point lookups still use sequential scans because Phase 2
  intentionally created no tuning indexes.
- The primary-key and unique constraints provide the only automatic indexes.
- Write queries also scan tables where no supporting index exists. Their
  timings are kept as the baseline for measuring the write overhead of Phase 4
  indexes.
