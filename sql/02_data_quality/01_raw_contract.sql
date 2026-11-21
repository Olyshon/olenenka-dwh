-- PostgreSQL 18. Validate input before any numeric casts or table replacement.
DO $$
DECLARE
    bad record;
BEGIN
    SELECT source_table, field
    INTO bad
    FROM (
        SELECT 'shop_order' AS source_table, v.*
        FROM raw.shop_order AS r
        CROSS JOIN LATERAL (VALUES
            ('id', r.id, 'bigint', TRUE),
            ('contact_id', r.contact_id, 'bigint', FALSE),
            ('total', r.total, 'numeric(20,4)', r.state_id IS NOT DISTINCT FROM 'completed'),
            ('discount', r.discount, 'numeric(20,4)', FALSE),
            ('shipping', r.shipping, 'numeric(20,4)', FALSE),
            ('create_datetime', r.create_datetime, 'timestamp without time zone', TRUE),
            ('assigned_contact_id', r.assigned_contact_id, 'bigint', FALSE),
            ('update_datetime', r.update_datetime, 'timestamp without time zone', FALSE),
            ('paid_date', r.paid_date, 'date', FALSE),
            ('tax', r.tax, 'numeric(20,4)', FALSE),
            ('rate', r.rate, 'numeric(20,8)', FALSE),
            ('paid_year', r.paid_year, 'integer', FALSE),
            ('paid_month', r.paid_month, 'integer', FALSE),
            ('paid_quarter', r.paid_quarter, 'integer', FALSE),
            ('is_first', r.is_first, 'integer', FALSE)
        ) AS v(field, val, target_type, required)
        UNION ALL
        SELECT 'shop_order_items', v.*
        FROM raw.shop_order_items AS r
        CROSS JOIN LATERAL (VALUES
            ('id', r.id, 'bigint', TRUE),
            ('order_id', r.order_id, 'bigint', TRUE),
            ('product_id', r.product_id, 'bigint', FALSE),
            ('sku_id', r.sku_id, 'bigint', FALSE),
            ('price', r.price, 'numeric(20,4)', TRUE),
            ('quantity', r.quantity, 'numeric(20,4)', TRUE),
            ('purchase_price', r.purchase_price, 'numeric(20,4)', FALSE),
            ('total_discount', r.total_discount, 'numeric(20,4)', FALSE)
        ) AS v(field, val, target_type, required)
        UNION ALL
        SELECT 'shop_product', v.*
        FROM raw.shop_product AS r
        CROSS JOIN LATERAL (VALUES
            ('id', r.id, 'bigint', TRUE),
            ('sku_id', r.sku_id, 'bigint', FALSE),
            ('category_id', r.category_id, 'bigint', FALSE),
            ('image_id', r.image_id, 'bigint', FALSE),
            ('create_datetime', r.create_datetime, 'timestamp without time zone', FALSE),
            ('price', r.price, 'numeric(20,4)', FALSE),
            ('min_price', r.min_price, 'numeric(20,4)', FALSE),
            ('max_price', r.max_price, 'numeric(20,4)', FALSE),
            ('count', r.count, 'numeric(20,4)', FALSE)
        ) AS v(field, val, target_type, required)
        UNION ALL
        SELECT 'shop_product_skus', v.*
        FROM raw.shop_product_skus AS r
        CROSS JOIN LATERAL (VALUES
            ('id', r.id, 'bigint', TRUE),
            ('product_id', r.product_id, 'bigint', TRUE),
            ('price', r.price, 'numeric(20,4)', FALSE),
            ('purchase_price', r.purchase_price, 'numeric(20,4)', FALSE),
            ('count', r.count, 'numeric(20,4)', FALSE)
        ) AS v(field, val, target_type, required)
        UNION ALL
        SELECT 'shop_category', v.*
        FROM raw.shop_category AS r
        CROSS JOIN LATERAL (VALUES
            ('id', r.id, 'bigint', TRUE),
            ('parent_id', r.parent_id, 'bigint', FALSE),
            ('depth', r.depth, 'integer', FALSE),
            ('left_key', r.left_key, 'integer', FALSE),
            ('right_key', r.right_key, 'integer', FALSE)
        ) AS v(field, val, target_type, required)
        UNION ALL
        SELECT 'shop_category_products', v.*
        FROM raw.shop_category_products AS r
        CROSS JOIN LATERAL (VALUES
            ('product_id', r.product_id, 'bigint', TRUE),
            ('category_id', r.category_id, 'bigint', TRUE)
        ) AS v(field, val, target_type, required)
    ) AS inputs
    WHERE CASE
        WHEN val IS NULL THEN required
        WHEN val = '' THEN required OR (source_table, field) IN
            (('shop_order', 'total'), ('shop_product', 'create_datetime'))
        ELSE NOT pg_input_is_valid(val, target_type)
             OR (target_type LIKE 'numeric%' AND btrim(val) !~ '^[+-]?[0-9]+([.][0-9]+)?$')
             OR (target_type IN ('date', 'timestamp without time zone')
                 AND LOWER(BTRIM(val)) IN ('infinity', '-infinity'))
    END
    LIMIT 1;

    IF FOUND THEN
        RAISE EXCEPTION 'Invalid or missing RAW field %.%', bad.source_table, bad.field;
    END IF;

    IF EXISTS (
SELECT 1 FROM raw.shop_order GROUP BY id::bigint HAVING COUNT(*) > 1
    ) THEN RAISE EXCEPTION 'Duplicate typed key in shop_order'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_order_items GROUP BY id::bigint HAVING COUNT(*) > 1
    ) THEN RAISE EXCEPTION 'Duplicate typed key in shop_order_items'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_product GROUP BY id::bigint HAVING COUNT(*) > 1
    ) THEN RAISE EXCEPTION 'Duplicate typed key in shop_product'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_product_skus GROUP BY id::bigint HAVING COUNT(*) > 1
    ) THEN RAISE EXCEPTION 'Duplicate typed key in shop_product_skus'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_category GROUP BY id::bigint HAVING COUNT(*) > 1
    ) THEN RAISE EXCEPTION 'Duplicate typed key in shop_category'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_category_products GROUP BY product_id::bigint,category_id::bigint HAVING COUNT(*) > 1
    ) THEN RAISE EXCEPTION 'Duplicate typed key in shop_category_products'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_order_items i LEFT JOIN raw.shop_order o ON i.order_id::bigint=o.id::bigint WHERE o.id IS NULL
    ) THEN RAISE EXCEPTION 'RAW item without order'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_product_skus s LEFT JOIN raw.shop_product p ON s.product_id::bigint=p.id::bigint WHERE p.id IS NULL
    ) THEN RAISE EXCEPTION 'RAW SKU without product'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_category_products l LEFT JOIN raw.shop_product p ON l.product_id::bigint=p.id::bigint LEFT JOIN raw.shop_category c ON l.category_id::bigint=c.id::bigint WHERE p.id IS NULL OR c.id IS NULL
    ) THEN RAISE EXCEPTION 'Broken RAW category link'; END IF;
    IF EXISTS (
SELECT 1 FROM raw.shop_category c LEFT JOIN raw.shop_category p
 ON NULLIF(NULLIF(c.parent_id,''),'0')::bigint=p.id::bigint
 WHERE (NULLIF(NULLIF(c.parent_id,''),'0') IS NOT NULL AND p.id IS NULL)
 OR p.id::bigint=c.id::bigint OR NULLIF(c.left_key,'')::integer >= NULLIF(c.right_key,'')::integer
    ) THEN RAISE EXCEPTION 'Invalid RAW category hierarchy'; END IF;
END
$$;
