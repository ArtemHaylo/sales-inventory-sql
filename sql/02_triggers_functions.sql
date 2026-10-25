-- =====================================================================
-- 02_triggers_functions.sql : business logic in PL/pgSQL
-- 3 triggers keep inventory consistent, 3 functions compute business metrics
-- =====================================================================

-- ---------------------------------------------------------------------
-- Trigger 1: a delivery date cannot be in the future
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_delivery_date_func()
RETURNS trigger AS $$
BEGIN
    IF NEW.delivery_date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Delivery date (%) cannot be in the future', NEW.delivery_date;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_delivery_date ON deliveries;
CREATE TRIGGER trg_check_delivery_date
BEFORE INSERT OR UPDATE ON deliveries
FOR EACH ROW EXECUTE FUNCTION check_delivery_date_func();

-- ---------------------------------------------------------------------
-- Trigger 2: a new delivery increases stock (creates a stock record if needed)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_inventory_on_delivery_func()
RETURNS trigger AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM inventory WHERE product_id = NEW.product_id) THEN
        UPDATE inventory
        SET quantity = quantity + NEW.quantity
        WHERE product_id = NEW.product_id;
    ELSE
        INSERT INTO inventory (product_id, quantity, warehouse)
        VALUES (NEW.product_id, NEW.quantity, 'Main Warehouse');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_inventory ON deliveries;
CREATE TRIGGER trg_update_inventory
AFTER INSERT ON deliveries
FOR EACH ROW EXECUTE FUNCTION update_inventory_on_delivery_func();

-- ---------------------------------------------------------------------
-- Trigger 3: an order line is accepted only if there is enough stock,
-- and the stock is written off
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION decrease_inventory_on_order_func()
RETURNS trigger AS $$
DECLARE
    current_stock INTEGER;
BEGIN
    SELECT SUM(quantity) INTO current_stock
    FROM inventory
    WHERE product_id = NEW.product_id;

    IF current_stock IS NULL OR current_stock < NEW.quantity THEN
        RAISE EXCEPTION 'Not enough stock for product % (requested %, available %)',
            NEW.product_id, NEW.quantity, COALESCE(current_stock, 0);
    END IF;

    UPDATE inventory
    SET quantity = quantity - NEW.quantity
    WHERE inventory_id = (
        SELECT inventory_id FROM inventory
        WHERE product_id = NEW.product_id AND quantity >= NEW.quantity
        LIMIT 1
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_decrease_inventory ON order_items;
CREATE TRIGGER trg_decrease_inventory
BEFORE INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION decrease_inventory_on_order_func();

-- ---------------------------------------------------------------------
-- Function 1: total value of an order (sum of quantity × price)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_order_total(p_order_id INTEGER)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_sum DECIMAL(10, 2);
BEGIN
    SELECT SUM(oi.quantity * p.price)
    INTO total_sum
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    WHERE oi.order_id = p_order_id;
    RETURN COALESCE(total_sum, 0);
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- Function 2: best-selling product by units sold
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_top_selling_product(OUT product_name VARCHAR, OUT total_sold BIGINT)
RETURNS record AS $$
BEGIN
    SELECT p.name, SUM(oi.quantity)
    INTO product_name, total_sold
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
    GROUP BY p.name
    ORDER BY SUM(oi.quantity) DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- Function 3: profit for a period = payments − refunds − delivery costs
-- (the original lab version ignored refunds; they are subtracted here)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION calculate_profit(start_date DATE, end_date DATE)
RETURNS DECIMAL(12, 2) AS $$
DECLARE
    total_income   DECIMAL(12, 2);
    total_refunds  DECIMAL(12, 2);
    total_expenses DECIMAL(12, 2);
BEGIN
    SELECT SUM(amount) INTO total_income
    FROM transactions
    WHERE "type" = 'payment' AND transaction_date::date BETWEEN start_date AND end_date;

    SELECT SUM(ABS(amount)) INTO total_refunds
    FROM transactions
    WHERE "type" = 'refund' AND transaction_date::date BETWEEN start_date AND end_date;

    SELECT SUM(cost) INTO total_expenses
    FROM deliveries
    WHERE delivery_date BETWEEN start_date AND end_date;

    RETURN COALESCE(total_income, 0) - COALESCE(total_refunds, 0) - COALESCE(total_expenses, 0);
END;
$$ LANGUAGE plpgsql;
