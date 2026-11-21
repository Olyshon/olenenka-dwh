DO $$
BEGIN
IF EXISTS (
SELECT 1
FROM raw.shop_order AS r
FULL OUTER JOIN staging.shop_order AS s ON r.id::BIGINT = s.order_id
WHERE r.id IS NULL
    OR s.order_id IS NULL
    OR r.total::NUMERIC IS DISTINCT
    FROM s.order_total
 OR r.create_datetime::timestamp IS DISTINCT FROM s.created_at
 OR NULLIF(r.paid_date,'')::date IS DISTINCT FROM s.paid_at
 OR r.state_id IS DISTINCT FROM s.order_status
 OR NULLIF(r.discount,'')::numeric(20,4) IS DISTINCT FROM s.discount
 OR NULLIF(r.shipping,'')::numeric(20,4) IS DISTINCT FROM s.shipping
 OR COALESCE(NULLIF(r.contact_id,'')::bigint IN (2263,4669),FALSE) IS DISTINCT FROM s.is_offline_service_account
 OR EXTRACT(YEAR FROM NULLIF(r.paid_date,'')::date) IS DISTINCT FROM s.paid_year
 OR EXTRACT(MONTH FROM NULLIF(r.paid_date,'')::date) IS DISTINCT FROM s.paid_month
 OR EXTRACT(QUARTER FROM NULLIF(r.paid_date,'')::date) IS DISTINCT FROM s.paid_quarter
 OR NULLIF(r.contact_id,'')::bigint IS DISTINCT FROM s.contact_id
 OR (r.state_id = 'completed') IS DISTINCT FROM s.is_completed
 OR (NULLIF(r.paid_date,'') IS NOT NULL) IS DISTINCT FROM s.has_paid_date
 OR (NULLIF(r.paid_date,'') IS NOT NULL AND
     (NULLIF(r.paid_month,'')::integer IS DISTINCT FROM s.paid_month OR
      NULLIF(r.paid_quarter,'')::integer IS DISTINCT FROM s.paid_quarter))
    IS DISTINCT FROM s.has_calendar_mismatch
    ) THEN RAISE EXCEPTION 'RAW to staging orders'; END IF;
    IF EXISTS (
SELECT 1
FROM raw.shop_order_items AS r
FULL OUTER JOIN staging.shop_order_items AS s ON r.id::BIGINT = s.item_id
WHERE r.id IS NULL
    OR s.item_id IS NULL
    OR r.order_id::BIGINT IS DISTINCT
    FROM s.order_id
    OR r.price::NUMERIC IS DISTINCT
    FROM s.unit_price
    OR r.quantity::NUMERIC IS DISTINCT
    FROM s.quantity
    OR NULLIF(r.purchase_price, '')::NUMERIC IS DISTINCT
    FROM s.purchase_price
    OR NULLIF(r.total_discount, '')::NUMERIC IS DISTINCT
    FROM s.total_discount
 OR NULLIF(r.product_id,'')::bigint IS DISTINCT FROM s.product_id
 OR NULLIF(r.sku_id,'')::bigint IS DISTINCT FROM s.sku_id
 OR (r.price::numeric*r.quantity::numeric)::numeric(20,4) IS DISTINCT FROM s.item_amount_before_discount
 OR r.name IS DISTINCT FROM s.item_name OR r.sku_code IS DISTINCT FROM s.sku_code
    ) THEN RAISE EXCEPTION 'RAW to staging items'; END IF;
    IF EXISTS (
SELECT 1
FROM raw.shop_product AS r
FULL OUTER JOIN staging.shop_product AS s ON r.id::BIGINT = s.product_id
WHERE r.id IS NULL
    OR s.product_id IS NULL
    OR r.name IS DISTINCT
    FROM s.product_name
    OR NULLIF(r.sku_id, '')::BIGINT IS DISTINCT
    FROM s.main_sku_id
    OR NULLIF(r.category_id, '')::BIGINT IS DISTINCT
    FROM s.main_category_id
    OR NULLIF(r.price, '')::NUMERIC IS DISTINCT
    FROM s.catalog_price
    OR NULLIF(r.min_price, '')::NUMERIC IS DISTINCT
    FROM s.min_price
    OR NULLIF(r.max_price, '')::NUMERIC IS DISTINCT
    FROM s.max_price
    OR NULLIF(r.count, '')::NUMERIC IS DISTINCT
    FROM s.stock_count
    OR r.status IS DISTINCT
    FROM s.product_status
    ) THEN RAISE EXCEPTION 'RAW to staging products'; END IF;
    IF EXISTS (
SELECT 1
FROM raw.shop_product_skus AS r
FULL OUTER JOIN staging.shop_product_skus AS s
    ON r.id::BIGINT = s.sku_id
WHERE r.id IS NULL
   OR s.sku_id IS NULL
   OR r.product_id::BIGINT IS DISTINCT FROM s.product_id
   OR NULLIF(r.sku, '') IS DISTINCT FROM s.sku_code
   OR NULLIF(r.name, '') IS DISTINCT FROM s.sku_name
   OR NULLIF(r.price, '')::NUMERIC IS DISTINCT FROM s.catalog_price
   OR NULLIF(r.purchase_price, '')::NUMERIC
      IS DISTINCT FROM s.catalog_purchase_price
   OR NULLIF(r.count, '')::NUMERIC IS DISTINCT FROM s.stock_count
    ) THEN RAISE EXCEPTION 'RAW to staging skus'; END IF;
    IF EXISTS (
SELECT 1
FROM raw.shop_category AS r
FULL OUTER JOIN staging.shop_category AS s
    ON r.id::BIGINT = s.category_id
WHERE r.id IS NULL
   OR s.category_id IS NULL
   OR NULLIF(NULLIF(r.parent_id, ''), '0')::BIGINT
      IS DISTINCT FROM s.parent_category_id
   OR NULLIF(r.depth, '')::INTEGER IS DISTINCT FROM s.depth
   OR NULLIF(r.left_key, '')::INTEGER IS DISTINCT FROM s.left_key
   OR NULLIF(r.right_key, '')::INTEGER IS DISTINCT FROM s.right_key
   OR r.name IS DISTINCT FROM s.category_name
   OR r.status IS DISTINCT FROM s.category_status
 OR (NULLIF(NULLIF(r.parent_id,''),'0') IS NULL) IS DISTINCT FROM s.is_root_category
    ) THEN RAISE EXCEPTION 'RAW to staging categories'; END IF;
    IF EXISTS (
SELECT 1
FROM raw.shop_category_products AS r
FULL OUTER JOIN staging.shop_category_products AS s
    ON r.product_id::BIGINT = s.product_id
   AND r.category_id::BIGINT = s.category_id
WHERE r.product_id IS NULL
   OR s.product_id IS NULL
   OR r.sort IS DISTINCT FROM s.sort_order_raw
    ) THEN RAISE EXCEPTION 'RAW to staging categories links'; END IF;
END
$$;
