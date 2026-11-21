DO $$
BEGIN
IF EXISTS (
SELECT 1
FROM staging.shop_order AS s
FULL OUTER JOIN mart.fact_orders AS f
    ON s.order_id = f.order_id
WHERE s.order_id IS NULL
   OR f.order_id IS NULL
   OR s.contact_id IS DISTINCT FROM f.contact_id
   OR s.created_at IS DISTINCT FROM f.created_at
   OR s.paid_at IS DISTINCT FROM f.paid_at
   OR s.order_status IS DISTINCT FROM f.order_status
   OR s.is_completed IS DISTINCT FROM f.is_completed
   OR s.is_offline_service_account
      IS DISTINCT FROM f.is_offline_service_account
   OR s.order_total IS DISTINCT FROM f.order_total
   OR COALESCE(s.discount, 0) IS DISTINCT FROM f.discount
   OR COALESCE(s.shipping, 0) IS DISTINCT FROM f.shipping
   OR COALESCE(s.tax, 0) IS DISTINCT FROM f.tax
   OR s.currency IS DISTINCT FROM f.currency
   OR s.created_at::DATE IS DISTINCT FROM f.order_date
   OR DATE_TRUNC('month', s.created_at)::DATE IS DISTINCT FROM f.order_month
   OR s.has_paid_date IS DISTINCT FROM f.has_paid_date
   OR CASE
        WHEN s.is_completed THEN s.order_total
        ELSE 0
      END IS DISTINCT FROM f.completed_order_amount
    ) THEN RAISE EXCEPTION 'Staging to mart orders'; END IF;
    IF EXISTS (
SELECT 1
FROM staging.shop_order_items AS s
FULL OUTER JOIN mart.fact_order_items AS f ON s.item_id = f.item_id
WHERE s.item_id IS NULL
    OR f.item_id IS NULL
    OR s.order_id IS DISTINCT
    FROM f.order_id
    OR NULLIF(s.product_id, 0) IS DISTINCT
    FROM f.product_id
    OR NULLIF(s.sku_id, 0) IS DISTINCT
    FROM f.sku_id
    OR s.item_name IS DISTINCT
    FROM f.item_name
    OR s.sku_code IS DISTINCT
    FROM f.sku_code
    OR s.quantity IS DISTINCT
    FROM f.quantity
    OR s.unit_price IS DISTINCT
    FROM f.unit_price
    OR s.item_amount_before_discount IS DISTINCT
    FROM f.item_amount_before_discount
    OR s.purchase_price IS DISTINCT
    FROM f.purchase_price
    OR s.total_discount IS DISTINCT
    FROM f.total_discount
    ) THEN RAISE EXCEPTION 'Staging to mart items'; END IF;
    IF EXISTS (
        SELECT 1
        FROM mart.fact_order_items AS i
        JOIN mart.fact_orders AS o USING (order_id)
        WHERE (i.order_date, i.order_month, i.order_status, i.is_completed,
               i.is_offline_service_account)
              IS DISTINCT FROM
              (o.order_date, o.order_month, o.order_status, o.is_completed,
               o.is_offline_service_account)
    ) THEN
        RAISE EXCEPTION 'Item order dates, status or account flag differ from order fact';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mart.fact_order_items AS i
        LEFT JOIN mart.dim_skus AS s USING (sku_id)
        WHERE i.sku_id IS NOT NULL
          AND (s.sku_id IS NULL OR s.product_id IS DISTINCT FROM i.product_id)
    ) THEN
        RAISE EXCEPTION 'An item SKU does not map to its recorded product';
    END IF;
    IF EXISTS (
SELECT 1 FROM mart.fact_order_items i
 LEFT JOIN mart.fact_orders o USING(order_id)
 LEFT JOIN mart.dim_products p ON p.product_id=i.product_id
 LEFT JOIN mart.dim_legacy_skus l USING(legacy_sku_key)
 WHERE o.order_id IS NULL OR (i.product_id IS NOT NULL AND p.product_id IS NULL)
 OR (i.legacy_sku_key IS NOT NULL AND l.legacy_sku_key IS NULL)
    ) THEN RAISE EXCEPTION 'Broken fact reference'; END IF;
    IF EXISTS (
SELECT 1 FROM mart.dim_skus s LEFT JOIN mart.dim_products p USING(product_id) WHERE p.product_id IS NULL
    ) THEN RAISE EXCEPTION 'SKU dimension without product'; END IF;
END
$$;

DO $$
BEGIN
    IF EXISTS (
WITH historical_items AS
    (SELECT item_id,
            SUBSTRING(item_name
                      FROM '^\[([^]]+)\]') AS historical_sku,
            LOWER(TRIM(REGEXP_REPLACE(REGEXP_REPLACE(item_name, '^\[[^]]+\]\s*', ''), '\s+', ' ', 'g'))) AS normalized_name
     FROM staging.shop_order_items
     WHERE product_id = 0
         AND sku_id = 0),
     sku_stats AS
    (SELECT historical_sku,
            COUNT(DISTINCT normalized_name) AS names_count
     FROM historical_items
     WHERE historical_sku IS NOT NULL
     GROUP BY historical_sku),
     items_with_keys AS
    (SELECT h.item_id,
            h.historical_sku,
            CASE
                WHEN h.historical_sku IS NOT NULL THEN 'legacy:' || MD5(h.historical_sku || '|' || CASE
                                                                                                       WHEN s.names_count > 1 THEN h.normalized_name
                                                                                                       ELSE ''
                                                                                                   END)
            END AS legacy_sku_key
     FROM historical_items AS h
     LEFT JOIN sku_stats AS s ON h.historical_sku = s.historical_sku)

SELECT 1
FROM items_with_keys AS i
LEFT JOIN mart.fact_order_items AS f ON f.item_id = i.item_id
LEFT JOIN mart.dim_legacy_skus AS d ON f.legacy_sku_key = d.legacy_sku_key
WHERE f.item_id IS NULL
   OR i.legacy_sku_key IS DISTINCT FROM f.legacy_sku_key
   OR (f.legacy_sku_key IS NOT NULL AND d.legacy_sku_key IS NULL)
    ) THEN
        RAISE EXCEPTION 'Legacy item key changed or its dimension is missing';
    END IF;
END
$$;
