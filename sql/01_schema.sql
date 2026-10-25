-- =====================================================================
-- ABC Corporation — Sales & Inventory database (PostgreSQL)
-- 01_schema.sql : tables, keys and integrity constraints
-- The schema is normalized to 3NF / BCNF (see README).
-- =====================================================================

DROP TABLE IF EXISTS deliveries, order_items, transactions, inventory,
                     orders, products, suppliers, employees, clients CASCADE;

CREATE TABLE clients (
    client_id   SERIAL PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE
                CHECK (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    phone       VARCHAR(20)  NOT NULL UNIQUE,
    address     VARCHAR(255)
);

CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    full_name   VARCHAR(150) NOT NULL,
    "position"  VARCHAR(100) NOT NULL,
    email       VARCHAR(100) NOT NULL UNIQUE
                CHECK (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    phone       VARCHAR(20)  NOT NULL UNIQUE,
    department  VARCHAR(50)
);

CREATE TABLE suppliers (
    supplier_id SERIAL PRIMARY KEY,
    name        VARCHAR(150) NOT NULL UNIQUE,
    email       VARCHAR(100) NOT NULL UNIQUE
                CHECK (email ~* '^[A-Za-z0-9._+%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'),
    phone       VARCHAR(20)  NOT NULL UNIQUE,
    address     VARCHAR(255) NOT NULL
);

CREATE TABLE products (
    product_id  SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    category    VARCHAR(100),
    description TEXT,
    price       DECIMAL(10, 2) NOT NULL CHECK (price >= 0)
);

CREATE TABLE orders (
    order_id     SERIAL PRIMARY KEY,
    order_date   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount DECIMAL(10, 2) NOT NULL CHECK (total_amount >= 0),
    client_id    INTEGER NOT NULL,
    employee_id  INTEGER NOT NULL,
    CONSTRAINT fk_order_client   FOREIGN KEY (client_id)   REFERENCES clients (client_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_order_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE inventory (
    inventory_id SERIAL PRIMARY KEY,
    quantity     INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
    warehouse    VARCHAR(100),
    product_id   INTEGER NOT NULL,
    employee_id  INTEGER,
    CONSTRAINT fk_inventory_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_inventory_employee FOREIGN KEY (employee_id) REFERENCES employees (employee_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE transactions (
    transaction_id   SERIAL PRIMARY KEY,
    transaction_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    amount           DECIMAL(10, 2) NOT NULL,
    "type"           VARCHAR(50) NOT NULL CHECK ("type" IN ('payment', 'refund')),
    order_id         INTEGER NOT NULL,
    CONSTRAINT fk_transaction_order FOREIGN KEY (order_id) REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Junction table that resolves the M:N relationship between orders and products
CREATE TABLE order_items (
    order_id   INTEGER NOT NULL,
    product_id INTEGER NOT NULL,
    quantity   INTEGER NOT NULL CHECK (quantity > 0),
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_item_order   FOREIGN KEY (order_id)   REFERENCES orders (order_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_item_product FOREIGN KEY (product_id) REFERENCES products (product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE deliveries (
    supplier_id   INTEGER NOT NULL,
    product_id    INTEGER NOT NULL,
    delivery_date DATE NOT NULL DEFAULT CURRENT_DATE,
    quantity      INTEGER NOT NULL CHECK (quantity > 0),
    cost          DECIMAL(10, 2) NOT NULL CHECK (cost >= 0),
    PRIMARY KEY (supplier_id, product_id, delivery_date),
    CONSTRAINT fk_delivery_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers (supplier_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_delivery_product  FOREIGN KEY (product_id)  REFERENCES products (product_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Indexes on foreign keys used in joins and date filters
CREATE INDEX idx_orders_client      ON orders (client_id);
CREATE INDEX idx_orders_employee    ON orders (employee_id);
CREATE INDEX idx_orders_date        ON orders (order_date);
CREATE INDEX idx_items_product      ON order_items (product_id);
CREATE INDEX idx_transactions_order ON transactions (order_id);
CREATE INDEX idx_inventory_product  ON inventory (product_id);
