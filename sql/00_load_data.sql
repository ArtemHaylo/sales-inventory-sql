-- =====================================================================
-- 00_load_data.sql : load the generated CSV files (run from the repo root)
--   psql -d abc_corp -f sql/01_schema.sql
--   psql -d abc_corp -f sql/02_triggers_functions.sql
--   psql -d abc_corp -f sql/00_load_data.sql
-- Deliveries are loaded before order lines, so the inventory triggers
-- first add stock and then write it off for every sold item.
-- =====================================================================
\copy employees    FROM 'data/csv/employees.csv'    WITH (FORMAT csv, HEADER true)
\copy suppliers    FROM 'data/csv/suppliers.csv'    WITH (FORMAT csv, HEADER true)
\copy products     FROM 'data/csv/products.csv'     WITH (FORMAT csv, HEADER true)
\copy clients      FROM 'data/csv/clients.csv'      WITH (FORMAT csv, HEADER true)
\copy deliveries   FROM 'data/csv/deliveries.csv'   WITH (FORMAT csv, HEADER true)
\copy orders       FROM 'data/csv/orders.csv'       WITH (FORMAT csv, HEADER true)
\copy order_items  FROM 'data/csv/order_items.csv'  WITH (FORMAT csv, HEADER true)
\copy transactions FROM 'data/csv/transactions.csv' WITH (FORMAT csv, HEADER true)

-- keep SERIAL sequences in sync with the loaded ids
SELECT setval('clients_client_id_seq',           (SELECT MAX(client_id)      FROM clients));
SELECT setval('employees_employee_id_seq',       (SELECT MAX(employee_id)    FROM employees));
SELECT setval('suppliers_supplier_id_seq',       (SELECT MAX(supplier_id)    FROM suppliers));
SELECT setval('products_product_id_seq',         (SELECT MAX(product_id)     FROM products));
SELECT setval('orders_order_id_seq',             (SELECT MAX(order_id)       FROM orders));
SELECT setval('transactions_transaction_id_seq', (SELECT MAX(transaction_id) FROM transactions));

ANALYZE;
