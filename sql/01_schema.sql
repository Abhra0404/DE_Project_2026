CREATE SCHEMA zomato;
SET search_path TO zomato;

CREATE TABLE cities (
    city_id integer PRIMARY KEY,
    city_name varchar(100) NOT NULL UNIQUE,
    state varchar(100) NOT NULL
);

CREATE TABLE localities (
    locality_id integer PRIMARY KEY,
    city_id integer NOT NULL REFERENCES cities(city_id),
    locality_name varchar(100) NOT NULL UNIQUE,
    pincode varchar(10) NOT NULL UNIQUE
);

CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    full_name varchar(150) NOT NULL,
    email varchar(254) NOT NULL UNIQUE,
    phone varchar(20) NOT NULL UNIQUE,
    city_id integer NOT NULL REFERENCES cities(city_id),
    signup_date date NOT NULL,
    is_gold_member boolean NOT NULL DEFAULT false,
    gold_expires_on date,
    is_active boolean NOT NULL DEFAULT true
);

CREATE TABLE restaurants (
    restaurant_id integer PRIMARY KEY,
    name varchar(150) NOT NULL UNIQUE,
    locality_id integer NOT NULL REFERENCES localities(locality_id),
    cuisines text[] NOT NULL,
    avg_cost_for_two numeric(10, 2) NOT NULL,
    rating numeric(2, 1),
    rating_count integer NOT NULL DEFAULT 0,
    opens_at time NOT NULL,
    closes_at time NOT NULL,
    is_pure_veg boolean NOT NULL DEFAULT false,
    status varchar(30) NOT NULL,
    onboarded_on date NOT NULL,
    CHECK (avg_cost_for_two > 0),
    CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
    CHECK (rating_count >= 0),
    CHECK (status IN ('OPEN', 'TEMPORARILY_CLOSED', 'DELISTED'))
);

CREATE TABLE menu_items (
    item_id integer PRIMARY KEY,
    restaurant_id integer NOT NULL REFERENCES restaurants(restaurant_id),
    item_name varchar(150) NOT NULL,
    category varchar(50) NOT NULL,
    price numeric(10, 2) NOT NULL,
    is_veg boolean NOT NULL DEFAULT false,
    is_bestseller boolean NOT NULL DEFAULT false,
    is_available boolean NOT NULL DEFAULT true,
    CHECK (category IN ('Beverages', 'Breads', 'Desserts', 'Main Course', 'Rice', 'Starters')),
    CHECK (price > 0)
);

CREATE TABLE delivery_partners (
    partner_id integer PRIMARY KEY,
    full_name varchar(150) NOT NULL,
    phone varchar(20) NOT NULL UNIQUE,
    city_id integer NOT NULL REFERENCES cities(city_id),
    vehicle_type varchar(20) NOT NULL,
    joined_on date NOT NULL,
    rating numeric(2, 1) NOT NULL,
    status varchar(20) NOT NULL,
    CHECK (vehicle_type IN ('BICYCLE', 'BIKE', 'EV', 'SCOOTER')),
    CHECK (rating BETWEEN 0 AND 5),
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'BLOCKED'))
);

CREATE TABLE coupons (
    coupon_code varchar(50) PRIMARY KEY,
    discount_pct numeric(5, 2) NOT NULL,
    max_discount numeric(10, 2) NOT NULL,
    min_order_value numeric(10, 2) NOT NULL,
    valid_from date NOT NULL,
    valid_to date NOT NULL,
    CHECK (discount_pct > 0 AND discount_pct <= 100),
    CHECK (max_discount > 0),
    CHECK (min_order_value >= 0)
);

CREATE TABLE orders (
    order_id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(customer_id),
    restaurant_id integer NOT NULL REFERENCES restaurants(restaurant_id),
    partner_id integer REFERENCES delivery_partners(partner_id),
    coupon_code varchar(50) REFERENCES coupons(coupon_code),
    placed_at timestamptz NOT NULL,
    accepted_at timestamptz,
    picked_up_at timestamptz,
    delivered_at timestamptz,
    distance_km numeric(8, 2) NOT NULL,
    item_total numeric(12, 2) NOT NULL,
    delivery_fee numeric(10, 2) NOT NULL,
    discount numeric(10, 2) NOT NULL DEFAULT 0,
    total_amount numeric(12, 2) NOT NULL,
    status varchar(30) NOT NULL,
    CHECK (distance_km > 0),
    CHECK (item_total >= 0),
    CHECK (delivery_fee >= 0),
    CHECK (discount >= 0),
    CHECK (total_amount >= 0)
);

CREATE TABLE order_items (
    order_id integer NOT NULL REFERENCES orders(order_id),
    item_id integer NOT NULL REFERENCES menu_items(item_id),
    quantity smallint NOT NULL,
    unit_price numeric(10, 2) NOT NULL,
    PRIMARY KEY (order_id, item_id),
    CHECK (quantity > 0),
    CHECK (unit_price > 0)
);

CREATE TABLE payments (
    payment_id integer PRIMARY KEY,
    order_id integer NOT NULL REFERENCES orders(order_id),
    amount numeric(12, 2) NOT NULL,
    method varchar(20) NOT NULL,
    payment_status varchar(20) NOT NULL,
    attempted_at timestamptz NOT NULL,
    CHECK (amount > 0),
    CHECK (method IN ('UPI', 'CARD', 'WALLET', 'COD')),
    CHECK (payment_status IN ('FAILED', 'SUCCESS', 'REFUNDED'))
);

CREATE TABLE reviews (
    review_id integer PRIMARY KEY,
    order_id integer NOT NULL UNIQUE REFERENCES orders(order_id),
    customer_id integer NOT NULL REFERENCES customers(customer_id),
    restaurant_id integer NOT NULL REFERENCES restaurants(restaurant_id),
    food_rating smallint NOT NULL,
    delivery_rating smallint,
    review_text text,
    created_at timestamptz NOT NULL,
    CHECK (food_rating BETWEEN 1 AND 5),
    CHECK (delivery_rating IS NULL OR delivery_rating BETWEEN 1 AND 5)
);
