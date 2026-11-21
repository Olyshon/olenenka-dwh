DO $$
BEGIN
IF (SELECT COUNT(*) FROM mart.fact_orders) <> 12894
       OR (SELECT COUNT(*) FROM mart.fact_order_items) <> 86896
       OR (SELECT COUNT(*) FROM mart.sales_monthly) <> 72
    THEN
        RAISE EXCEPTION 'Historical snapshot row counts changed';
    END IF;

    IF (SELECT COUNT(*) FROM raw.shop_order) <> 12894
       OR (SELECT COUNT(*) FROM raw.shop_order_items) <> 86896
       OR (SELECT COUNT(*) FROM raw.shop_product) <> 3611
       OR (SELECT COUNT(*) FROM raw.shop_product_skus) <> 3938
       OR (SELECT COUNT(*) FROM raw.shop_category) <> 164
       OR (SELECT COUNT(*) FROM raw.shop_category_products) <> 3728 THEN
        RAISE EXCEPTION 'Historical RAW row counts changed';
    END IF;

    IF (SELECT COUNT(*) FROM mart.dim_legacy_skus) <> 878 THEN
        RAISE EXCEPTION 'Historical SKU group count changed';
    END IF;
    IF EXISTS (
WITH expected(order_id,residual) AS (VALUES
        (8725::bigint, 0.5000::numeric),
        (9028::bigint, 5.0000::numeric),
        (9434::bigint, 0.5000::numeric),
        (10864::bigint, 0.1000::numeric),
        (10865::bigint, 4.5000::numeric),
        (10866::bigint, 0.7500::numeric),
        (10869::bigint, 0.2500::numeric),
        (10882::bigint, 0.7000::numeric),
        (10889::bigint, 0.2000::numeric),
        (10911::bigint, 0.7000::numeric),
        (11037::bigint, 0.1000::numeric),
        (11077::bigint, 0.3000::numeric),
        (11542::bigint, 0.5000::numeric)
), actual AS (
 SELECT order_id,residual_amount FROM mart.order_financial_reconciliation
 WHERE order_date >= DATE '2013-01-01' AND order_date < DATE '2019-01-01'
 AND reconciliation_status='mismatch'
)
SELECT 1 FROM expected e FULL JOIN actual a USING(order_id)
WHERE e.order_id IS NULL OR a.order_id IS NULL OR a.residual_amount IS NULL
 OR ABS(e.residual-a.residual_amount)>0.000001
    ) THEN RAISE EXCEPTION 'Historical exception IDs or amounts changed'; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM mart.order_financial_reconciliation
        WHERE reconciliation_status='no_items' AND order_id=1492
          AND order_date=DATE '2012-06-05'
    ) OR EXISTS (
        SELECT 1 FROM mart.order_financial_reconciliation
        WHERE reconciliation_status='no_items'
          AND (order_id,order_date) IS DISTINCT FROM (1492::bigint,DATE '2012-06-05')
    ) THEN RAISE EXCEPTION 'Historical no-items exception changed'; END IF;
END
$$;
-- Baseline for the historical snapshot covered by this release.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM mart.order_financial_reconciliation
        WHERE order_date >= DATE '2013-01-01' AND order_date < DATE '2019-01-01'
        HAVING COUNT(*) = 10420
           AND SUM(item_count) = 61057
           AND SUM(order_total) = 3103656.8900
           AND SUM(shipping) = 73975.1000
           AND ABS(SUM(items_after_discount) - 3029667.6830) <= 0.000001
           AND ABS(SUM(residual_amount) - 14.1070) <= 0.000001
           AND COUNT(*) FILTER (WHERE reconciliation_status = 'mismatch') = 13
    ) THEN
        RAISE EXCEPTION 'Historical financial baseline changed';
    END IF;
END
$$;

SELECT COUNT(*) AS completed_orders,
       SUM(order_total) AS order_total,
       SUM(items_after_discount) AS items_after_discount,
       SUM(shipping) AS shipping,
       SUM(residual_amount) AS residual_amount,
       COUNT(*) FILTER (WHERE reconciliation_status = 'mismatch') AS mismatch_orders
FROM mart.order_financial_reconciliation
WHERE order_date >= DATE '2013-01-01' AND order_date < DATE '2019-01-01';

SELECT order_id, order_date, items_after_discount, shipping, residual_amount, order_total
FROM mart.order_financial_reconciliation
WHERE order_date >= DATE '2013-01-01' AND order_date < DATE '2019-01-01'
  AND reconciliation_status = 'mismatch'
ORDER BY order_date, order_id;


-- Контрольные ориентиры ABC/XYZ относятся только к этому снимку.
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM mart.sales_by_sku) <> 5709
       OR (SELECT COUNT(*) FROM mart.sku_sales_monthly) <> 37653
       OR (SELECT COUNT(*) FROM mart.abc_xyz_skus) <> 5709
       OR NOT EXISTS (
           SELECT 1 FROM mart.abc_skus
           HAVING COUNT(*) = 5709
              AND COUNT(*) FILTER (WHERE abc_class = 'A') = 1829
              AND COUNT(*) FILTER (WHERE abc_class = 'B') = 1894
              AND COUNT(*) FILTER (WHERE abc_class = 'C') = 1982
              AND COUNT(*) FILTER (WHERE abc_class IS NULL) = 4
       )
       OR NOT EXISTS (
           SELECT 1 FROM mart.xyz_skus
           HAVING COUNT(*) = 5705
              AND COUNT(*) FILTER (WHERE xyz_relative_class = 'X') = 962
              AND COUNT(*) FILTER (WHERE xyz_relative_class = 'Y') = 962
              AND COUNT(*) FILTER (WHERE xyz_relative_class = 'Z') = 961
              AND COUNT(*) FILTER (WHERE xyz_status = 'INSUFFICIENT_HISTORY'
                                   AND xyz_relative_class IS NULL) = 2820
       )
    THEN
        RAISE EXCEPTION 'Historical assortment or ABC/XYZ control counts changed';
    END IF;

    -- Исторические заказы оформлены в RUB с курсом 1.
    -- Поле tax не используется в финансовой модели DWH: налоговый учёт в Webasyst не велся.
    IF EXISTS (
        SELECT 1
        FROM raw.shop_order
        WHERE currency IS DISTINCT FROM 'RUB'
           OR NULLIF(rate, '')::NUMERIC IS DISTINCT FROM 1
    ) THEN
        RAISE EXCEPTION 'Historical currency or rate assumptions changed';
    END IF;
END;
$$;

-- 8. Контрольная сводка ABC.
-- Исключённые группы отображаются отдельно.

SELECT
    COALESCE(abc_class, 'EXCLUDED') AS abc_class,
    COUNT(*) AS sku_groups,
    ROUND(SUM(sales_amount), 2) AS sales_amount
FROM mart.abc_skus
GROUP BY COALESCE(abc_class, 'EXCLUDED')
ORDER BY abc_class;


-- 9. Контрольная сводка XYZ.
-- NOT_CLASSIFIED: история наблюдения менее 12 месяцев.

SELECT
    COALESCE(
        xyz_relative_class,
        'NOT_CLASSIFIED'
    ) AS xyz_class,
    COUNT(*) AS sku_groups,
    ROUND(MIN(cv_pct), 2) AS min_cv_pct,
    ROUND(MAX(cv_pct), 2) AS max_cv_pct
FROM mart.xyz_skus
GROUP BY COALESCE(
    xyz_relative_class,
    'NOT_CLASSIFIED'
)
ORDER BY xyz_class;
