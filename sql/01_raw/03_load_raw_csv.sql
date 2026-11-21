-- Optional server-side import. Skip on the prepared test snapshot.
BEGIN;
DO $$
BEGIN
    IF current_database() <> 'olenenka_dwh_test' THEN
        RAISE EXCEPTION 'Connect to olenenka_dwh_test';
    END IF;
END
$$;
LOCK TABLE raw.shop_order, raw.shop_order_items, raw.shop_product, raw.shop_product_skus, raw.shop_category, raw.shop_category_products IN SHARE ROW EXCLUSIVE MODE;
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM raw.shop_order)
       OR EXISTS (SELECT 1 FROM raw.shop_order_items)
       OR EXISTS (SELECT 1 FROM raw.shop_product)
       OR EXISTS (SELECT 1 FROM raw.shop_product_skus)
       OR EXISTS (SELECT 1 FROM raw.shop_category)
       OR EXISTS (SELECT 1 FROM raw.shop_category_products) THEN
        RAISE EXCEPTION 'RAW already populated';
    END IF;
END
$$;
COPY raw.shop_order FROM 'C:/olenenka_data/shop_order_raw.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY raw.shop_order_items FROM 'C:/olenenka_data/shop_order_items_raw.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY raw.shop_product FROM 'C:/olenenka_data/shop_product_raw.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY raw.shop_product_skus FROM 'C:/olenenka_data/shop_product_skus_raw.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY raw.shop_category FROM 'C:/olenenka_data/shop_category_raw.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COPY raw.shop_category_products FROM 'C:/olenenka_data/shop_category_products_raw.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8');
COMMIT;
