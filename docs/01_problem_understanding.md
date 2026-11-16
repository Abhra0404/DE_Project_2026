# Phase 1: Problem Understanding

Zomato operates across 10 Indian cities, with 10 localities per city. Customers
discover restaurants and dishes, place and pay for orders, and may review
delivered orders. Restaurants prepare orders, delivery partners fulfil them,
and operations teams monitor the live order and fleet workflow.

| Problem | Business need and affected stakeholder | Classification |
|---|---|---|
| **P1. Home feed and restaurant pages** | Customers need fast locality-based restaurant discovery and restaurant details, especially at meal-time peaks. **Stakeholder:** customer. | Customer-facing / real-time |
| **P2. Dish search** | Customers need responsive type-ahead search for available dishes such as paneer and biryani. **Stakeholder:** customer. | Customer-facing / real-time |
| **P3. Order history and bills** | Customers need their recent orders, restaurant details, items and payment information to open quickly. **Stakeholder:** customer. | Customer-facing / real-time |
| **P4. Restaurant orders and sales** | Restaurant partners need current orders and dish-level sales for preparation and business decisions. **Stakeholder:** restaurant partner. | Customer-facing / real-time |
| **P5. Dispatch and kitchen delays** | Dispatch/ops staff need frequent refreshes of unassigned orders and orders delayed in the kitchen so they can intervene. **Stakeholder:** dispatch/ops. | Customer-facing / real-time |
| **P6. Idle delivery partners** | Fleet staff need a reliable list of active partners without recent assignments so capacity can be allocated correctly. **Stakeholder:** delivery partner / fleet team. | Customer-facing / real-time |
| **P7. Payment failures and risk** | Payments and risk teams need near-real-time failure and suspicious-customer visibility for investigation and intervention. **Stakeholder:** payments/risk. | Customer-facing / real-time |
| **P8. Gold, coupon and growth reports** | Gold and marketing teams need timely membership, coupon effectiveness and customer-growth aggregates for decisions and campaigns. **Stakeholder:** Gold team / marketing. | Reporting / analytics |
| **P9. Late deliveries and angry reviews** | Support and moderation staff need fast searches for late deliveries and complaint text so cases can be resolved. **Stakeholder:** support. | Customer-facing / real-time |
| **P10. Leadership dashboards** | Operations and leadership need delivery-time trends, order heatmaps and restaurant-health metrics that remain usable as volume grows 20x. **Stakeholder:** admin / leadership. | Reporting / analytics |

## Assumptions

- “Real-time” means interactive operational data or a refresh every few
  seconds; it does not require physically synchronous processing.
- Locality is the primary service area for restaurant discovery; a customer's
  city and a restaurant's locality determine geographic reporting.
- An order may have multiple payment attempts, but successful payment and
  delivery/order-status rules will be derived from the exported data before
  constraints are finalized.
- Nullable order assignment and lifecycle timestamps are expected while an
  order is still progressing or is cancelled. Gold expiry is nullable for
  non-Gold customers.
- Reporting queries may use precomputed aggregates or summaries in later
  phases, but their results must remain equivalent to the supplied workload.

## Data verification performed

The supplied CSV exports were checked before documenting the problem:

- Counts match the brief: 10 cities, 100 localities, 25,000 customers, 2,500
  restaurants, 50,000 menu items, 2,000 delivery partners, 30 coupons,
  150,000 orders, 375,000 order items, 137,378 payments and 39,186 reviews.
- Every city has exactly 10 localities.
- All order customer and restaurant references are valid; every assigned
  delivery partner reference is valid.
- No payment or review references a missing order.
- The exports contain 13,538 unassigned orders and 21,208 customers with no
  Gold expiry date, confirming that these fields must be handled as nullable
  during schema design.

These checks verify the documented structural facts, not the truth of
customer-entered text or business decisions such as review sentiment.
