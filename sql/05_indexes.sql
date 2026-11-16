SET search_path TO zomato;

-- Supports city-based restaurant joins in R02, R08, R09, R22, and R25.
CREATE INDEX idx_localities_city
ON localities (city_id, locality_id);

-- Supports the locality/status filters and rating sort in R01 and R25.
CREATE INDEX idx_restaurants_locality_status_rating
ON restaurants (locality_id, status, rating DESC NULLS LAST);

-- Supports array membership checks such as 'Chinese' = ANY(cuisines) in R25.
CREATE INDEX idx_restaurants_cuisines_gin
ON restaurants USING GIN (cuisines);

-- Supports restaurant menu filtering and ordering in R03.
CREATE INDEX idx_menu_items_restaurant_available_category
ON menu_items (
    restaurant_id,
    is_available,
    category,
    is_bestseller DESC,
    item_name
);

-- Supports the restaurant/category update in W03.
CREATE INDEX idx_menu_items_restaurant_category
ON menu_items (restaurant_id, category);

-- Supports recent-order lookup for a customer in R04 and customer-based
-- existence/join lookups in R14 and R20.
CREATE INDEX idx_orders_customer_placed
ON orders (customer_id, placed_at DESC);

-- Supports restaurant/date filtering in R06 and the restaurant subqueries in R19.
CREATE INDEX idx_orders_restaurant_placed
ON orders (restaurant_id, placed_at);

-- Supports delivered-order aggregation by restaurant in R07, R08, and R19.
CREATE INDEX idx_orders_restaurant_delivered_placed
ON orders (restaurant_id, placed_at)
WHERE status = 'DELIVERED';

-- Supports the delayed PREPARING-order alert in R05.
CREATE INDEX idx_orders_preparing_accepted
ON orders (accepted_at)
WHERE status = 'PREPARING';

-- Supports oldest unassigned-order lookup in R12 and W02.
CREATE INDEX idx_orders_unassigned_placed
ON orders (placed_at)
WHERE partner_id IS NULL
  AND status IN ('PLACED', 'ACCEPTED');

-- Supports partner delivery history in R11.
CREATE INDEX idx_orders_partner_delivered_placed
ON orders (partner_id, placed_at)
WHERE status = 'DELIVERED';

-- Supports newest-order pagination in R23 and time-window filtering in R10,
-- R21, and R22 without requiring table visits for the selected columns.
CREATE INDEX idx_orders_placed_covering
ON orders (placed_at DESC)
INCLUDE (order_id, customer_id, restaurant_id, status, total_amount);

-- Supports delivered-order coupon aggregation in R15.
CREATE INDEX idx_orders_coupon_delivered
ON orders (coupon_code)
WHERE status = 'DELIVERED';

-- Supports city-based customer grouping in R20 and R21.
CREATE INDEX idx_customers_city
ON customers (city_id, customer_id);

-- Supports Gold expiry filtering in R14 and W05 while indexing only Gold members.
CREATE INDEX idx_customers_gold_expiry
ON customers (gold_expires_on)
WHERE is_gold_member;

-- Supports failed-payment time filtering and method grouping in R16.
CREATE INDEX idx_payments_status_attempted
ON payments (payment_status, attempted_at)
INCLUDE (method);

-- Supports successful-payment lookup for a bill in R24.
CREATE INDEX idx_payments_success_order
ON payments (order_id)
WHERE payment_status = 'SUCCESS';

-- Supports failed-payment aggregation by customer in R17.
CREATE INDEX idx_payments_failed_order
ON payments (order_id)
WHERE payment_status = 'FAILED';

-- Supports restaurant review aggregation in R19 and W04.
CREATE INDEX idx_reviews_restaurant
ON reviews (restaurant_id)
INCLUDE (food_rating);
