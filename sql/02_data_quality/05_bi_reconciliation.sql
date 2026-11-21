
-- Olenenka DWH
-- Data Quality: сверка аналитических витрин с исходными фактами.
--
-- Проверки:
-- 1. Продажи по SKU относительно факта товарных позиций.
-- 2. Месячные продажи относительно факта заказов.
-- 3. Корректность исключения технических карточек.
-- 4. Полнота и правильность ABC-классификации.
-- 5. Сверка помесячных и общих продаж по SKU.
-- 6. Корректность расчётов и классификации XYZ.
-- 7. Сверка итоговой ABC-XYZ-витрины с исходными ABC и XYZ.

-- Контрольные сводки:
-- 8. Распределение товарных групп по ABC-классам.
-- 9. Распределение товарных групп по XYZ-классам.


-- 1. Сверка продаж по SKU с фактом товарных позиций.

DO $$
BEGIN
    IF EXISTS (
        WITH expected AS (
            SELECT
                CASE
                    WHEN sku_id IS NOT NULL
                        THEN 'sku:' || sku_id::TEXT
                    ELSE COALESCE(legacy_sku_key, 'unidentified')
                END AS product_key,
                COUNT(*) AS lines,
                COUNT(DISTINCT order_id) AS orders,
                SUM(quantity) AS units,
                SUM(item_amount_before_discount) AS gross,
                SUM(item_amount_after_discount) AS net
            FROM mart.fact_order_items
            WHERE is_completed
              AND order_date >= DATE '2013-01-01'
              AND order_date < DATE '2019-01-01'
            GROUP BY 1
        )

        SELECT 1
        FROM expected AS e
        FULL OUTER JOIN mart.sales_by_sku AS a
            USING (product_key)
        WHERE e.product_key IS NULL
           OR a.product_key IS NULL
           OR e.lines IS DISTINCT FROM a.order_items_count
           OR e.orders IS DISTINCT FROM a.orders_count
           OR e.units IS DISTINCT FROM a.sold_quantity
           OR e.gross IS DISTINCT FROM a.amount_before_discount
           OR e.net IS DISTINCT FROM a.sales_amount
    ) THEN
        RAISE EXCEPTION
            'SKU aggregates differ from item fact';
    END IF;
END;
$$;


-- 2. Сверка месячных показателей с фактом заказов.

DO $$
BEGIN
    IF EXISTS (
        WITH expected AS (
            SELECT
                order_month,
                COUNT(*) AS orders,
                SUM(order_total) AS amount,
                ROUND(AVG(order_total), 2) AS avg_amount,

                COUNT(*) FILTER (
                    WHERE is_offline_service_account
                ) AS offline_orders,

                COALESCE(
                    SUM(order_total) FILTER (
                        WHERE is_offline_service_account
                    ), 0
                ) AS offline_amount,

                COUNT(*) FILTER (
                    WHERE is_offline_service_account IS NOT TRUE
                ) AS other_orders,

                COALESCE(
                    SUM(order_total) FILTER (
                        WHERE is_offline_service_account IS NOT TRUE
                    ), 0
                ) AS other_amount

            FROM mart.fact_orders
            WHERE is_completed
              AND order_date >= DATE '2013-01-01'
              AND order_date < DATE '2019-01-01'
            GROUP BY order_month
        )

        SELECT 1
        FROM expected AS e
        FULL OUTER JOIN mart.sales_monthly AS a
            USING (order_month)
        WHERE e.order_month IS NULL
           OR a.order_month IS NULL

           OR (
               e.orders,
               e.amount,
               e.avg_amount,
               e.offline_orders,
               e.offline_amount,
               e.other_orders,
               e.other_amount
           ) IS DISTINCT FROM (
               a.completed_orders,
               a.completed_amount,
               a.avg_order_total,
               a.known_offline_orders,
               a.known_offline_amount,
               a.other_orders,
               a.other_amount
           )

           OR a.completed_orders IS DISTINCT FROM
               a.known_offline_orders + a.other_orders

           OR a.completed_amount IS DISTINCT FROM
               a.known_offline_amount + a.other_amount
    ) THEN
        RAISE EXCEPTION
            'Monthly metrics differ from order fact';
    END IF;
END;
$$;


-- 3. Проверка флага технических карточек.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM mart.sales_by_sku AS a
        LEFT JOIN mart.product_exclusions AS e
            USING (product_key)
        WHERE a.is_placeholder IS DISTINCT FROM
              (e.product_key IS NOT NULL)
    ) THEN
        RAISE EXCEPTION
            'Wrong technical-card flag';
    END IF;
END;
$$;


-- 4. Проверка полноты и правильности ABC-классификации.
--
-- Классы рассчитываются повторно по исходному обороту.
-- Товары с одинаковым оборотом получают одинаковый класс.
-- Группа, пересекающая порог 80% или 95%,
-- полностью остаётся в предыдущем классе.

DO $$
BEGIN
    IF EXISTS (
        WITH eligible AS (
            SELECT
                product_key,
                sales_amount
            FROM mart.sales_by_sku
            WHERE is_placeholder IS FALSE
              AND product_key <> 'unidentified'
              AND sales_amount > 0
        ),

        amount_groups AS (
            SELECT
                sales_amount,
                SUM(sales_amount) AS group_sales
            FROM eligible
            GROUP BY sales_amount
        ),

        ranked_groups AS (
            SELECT
                sales_amount,
                group_sales,
                SUM(group_sales) OVER (
                    ORDER BY sales_amount DESC
                    ROWS BETWEEN UNBOUNDED PRECEDING
                             AND CURRENT ROW
                ) AS cumulative_sales,
                SUM(group_sales) OVER () AS total_sales
            FROM amount_groups
        ),

        expected_classes AS (
            SELECT
                sales_amount,
                CASE
                    WHEN (cumulative_sales - group_sales)
                         / total_sales < 0.80 THEN 'A'
                    WHEN (cumulative_sales - group_sales)
                         / total_sales < 0.95 THEN 'B'
                    ELSE 'C'
                END AS abc_class
            FROM ranked_groups
        ),

        expected AS (
            SELECT
                s.*,
                c.abc_class,
                CASE
                    WHEN s.is_placeholder
                        THEN 'Техническая карточка'
                    WHEN s.product_key = 'unidentified'
                        THEN 'Неопознанный товар'
                    WHEN s.sales_amount <= 0
                        THEN 'Неположительный оборот'
                END AS exclusion_reason
            FROM mart.sales_by_sku AS s
            LEFT JOIN expected_classes AS c
                ON s.sales_amount = c.sales_amount
               AND s.is_placeholder IS FALSE
               AND s.product_key <> 'unidentified'
               AND s.sales_amount > 0
        )

        SELECT 1
        FROM expected AS e
        FULL OUTER JOIN mart.abc_skus AS a
            ON e.product_key = a.product_key

        WHERE e.product_key IS NULL
           OR a.product_key IS NULL

           OR (
               e.product_name,
               e.sku_id,
               e.product_id,
               e.legacy_sku_key,
               e.order_items_count,
               e.orders_count,
               e.sold_quantity,
               e.sales_amount,
               e.is_placeholder,
               e.abc_class,
               e.exclusion_reason
           ) IS DISTINCT FROM (
               a.product_name,
               a.sku_id,
               a.product_id,
               a.legacy_sku_key,
               a.order_items_count,
               a.orders_count,
               a.sold_quantity,
               a.sales_amount,
               a.is_placeholder,
               a.abc_class,
               a.exclusion_reason
           )

    ) THEN
        RAISE EXCEPTION
            'ABC reconciliation failed';
    END IF;
END;
$$;


-- 5. Сверка помесячной витрины SKU
-- с общей витриной продаж по товарным группам.

DO $$
BEGIN
    IF EXISTS (
        WITH monthly_totals AS (
            SELECT
                product_key,
                SUM(order_items_count) AS order_items_count,
                SUM(sold_quantity) AS sold_quantity,
                SUM(amount_before_discount) AS amount_before_discount,
                SUM(sales_amount) AS sales_amount
            FROM mart.sku_sales_monthly
            GROUP BY product_key
        )

        SELECT 1
        FROM mart.sales_by_sku AS s
        FULL OUTER JOIN monthly_totals AS m
            ON s.product_key = m.product_key

        WHERE s.product_key IS NULL
           OR m.product_key IS NULL
           OR s.order_items_count IS DISTINCT FROM
               m.order_items_count
           OR s.sold_quantity IS DISTINCT FROM
               m.sold_quantity
           OR s.amount_before_discount IS DISTINCT FROM
               m.amount_before_discount
           OR s.sales_amount IS DISTINCT FROM
               m.sales_amount

    ) THEN
        RAISE EXCEPTION
            'Monthly SKU totals differ from SKU aggregates';
    END IF;
END;
$$;

-- Сверка каждого товарного ключа и месяца с фактом.
DO $$
BEGIN
    IF EXISTS (
        WITH expected AS (
            SELECT
                CASE WHEN sku_id IS NOT NULL THEN 'sku:' || sku_id::TEXT
                     ELSE COALESCE(legacy_sku_key, 'unidentified') END AS product_key,
                order_month,
                COUNT(*) AS order_items_count,
                COUNT(DISTINCT order_id) AS orders_count,
                SUM(quantity) AS sold_quantity,
                SUM(item_amount_before_discount) AS amount_before_discount,
                SUM(item_amount_after_discount) AS sales_amount
            FROM mart.fact_order_items
            WHERE is_completed
              AND order_date >= DATE '2013-01-01'
              AND order_date < DATE '2019-01-01'
            GROUP BY 1, 2
        )
        SELECT 1
        FROM expected AS e
        FULL JOIN mart.sku_sales_monthly AS m USING (product_key, order_month)
        WHERE e.product_key IS NULL OR m.product_key IS NULL
           OR (e.order_items_count, e.orders_count, e.sold_quantity,
               e.amount_before_discount, e.sales_amount)
              IS DISTINCT FROM
              (m.order_items_count, m.orders_count, m.sold_quantity,
               m.amount_before_discount, m.sales_amount)
    ) THEN
        RAISE EXCEPTION
            'Monthly SKU metrics differ from item fact by key and month';
    END IF;
END;
$$;


-- 6. Проверка расчётов и классификации XYZ.
--
-- Проверяем:
-- - соответствие состава XYZ классифицируемым группам ABC;
-- - даты первой и последней положительной продажи;
-- - количество месяцев с продажами и период наблюдения;
-- - средние продажи, стандартное отклонение и CV;
-- - корректность классов по неокруглённым терцилям;
-- - статус недостаточной истории (менее 12 месяцев).
--
-- Метрика: количество проданных единиц за месяц.
-- Промежуточные месяцы без продаж учитываются как нули.

DO $$
BEGIN
    IF EXISTS (
        WITH history AS (
            SELECT
                a.product_key,

                MIN(m.order_month) FILTER (
                    WHERE m.sold_quantity > 0
                ) AS first_sale_month,

                MAX(m.order_month) FILTER (
                    WHERE m.sold_quantity > 0
                ) AS last_sale_month,

                COUNT(*) FILTER (
                    WHERE m.sold_quantity > 0
                ) AS months_with_sales

            FROM mart.abc_skus AS a
            LEFT JOIN mart.sku_sales_monthly AS m
                ON a.product_key = m.product_key

            WHERE a.abc_class IS NOT NULL
            GROUP BY a.product_key
        ),

        monthly_series AS (
            SELECT
                h.product_key,
                gs.month::DATE AS order_month,
                COALESCE(m.sold_quantity, 0) AS sold_quantity

            FROM history AS h

            CROSS JOIN LATERAL GENERATE_SERIES(
                h.first_sale_month,
                h.last_sale_month,
                INTERVAL '1 month'
            ) AS gs(month)

            LEFT JOIN mart.sku_sales_monthly AS m
                ON m.product_key = h.product_key
               AND m.order_month = gs.month::DATE
        ),

        variation AS (
            SELECT
                product_key,
                COUNT(*) AS observation_months,
                AVG(sold_quantity) AS avg_monthly_units,
                STDDEV_POP(sold_quantity) AS stddev_monthly_units,

                100.0 * STDDEV_POP(sold_quantity)
                    / NULLIF(AVG(sold_quantity), 0) AS cv_pct

            FROM monthly_series
            GROUP BY product_key
        ),

        thresholds AS (
            SELECT
                PERCENTILE_CONT(1.0 / 3.0)
                    WITHIN GROUP (ORDER BY cv_pct) AS x_limit,

                PERCENTILE_CONT(2.0 / 3.0)
                    WITHIN GROUP (ORDER BY cv_pct) AS y_limit

            FROM variation
            WHERE observation_months >= 12
              AND cv_pct IS NOT NULL
        ),

        expected AS (
            SELECT
                h.product_key,
                h.first_sale_month,
                h.last_sale_month,
                h.months_with_sales,

                v.observation_months,
                v.avg_monthly_units,
                v.stddev_monthly_units,
                v.cv_pct,

                CASE
                    WHEN v.observation_months < 12
                        THEN NULL
                    WHEN v.cv_pct <= t.x_limit
                        THEN 'X'
                    WHEN v.cv_pct <= t.y_limit
                        THEN 'Y'
                    ELSE 'Z'
                END AS xyz_relative_class,

                CASE
                    WHEN v.observation_months < 12
                        THEN 'INSUFFICIENT_HISTORY'
                    ELSE 'CLASSIFIED'
                END AS xyz_status

            FROM history AS h
            JOIN variation AS v
                ON h.product_key = v.product_key
            CROSS JOIN thresholds AS t
        )

        SELECT 1
        FROM expected AS e
        FULL OUTER JOIN mart.xyz_skus AS x
            ON e.product_key = x.product_key

        WHERE e.product_key IS NULL
           OR x.product_key IS NULL
           OR x.cv_pct IS NULL
           OR x.avg_monthly_units IS NULL OR x.avg_monthly_units <= 0

           OR (
               e.first_sale_month,
               e.last_sale_month,
               e.months_with_sales,
               e.observation_months,
               e.xyz_relative_class,
               e.xyz_status
           ) IS DISTINCT FROM (
               x.first_sale_month,
               x.last_sale_month,
               x.months_with_sales,
               x.observation_months,
               x.xyz_relative_class,
               x.xyz_status
           )

           OR ROUND(e.avg_monthly_units, 6)
              IS DISTINCT FROM
              ROUND(x.avg_monthly_units, 6)

           OR ROUND(e.stddev_monthly_units, 6)
              IS DISTINCT FROM
              ROUND(x.stddev_monthly_units, 6)

           OR ROUND(e.cv_pct, 6)
              IS DISTINCT FROM
              ROUND(x.cv_pct, 6)

    ) THEN
        RAISE EXCEPTION
            'XYZ reconciliation failed';
    END IF;
END;
$$;

-- Проверка состава XYZ независимо от календарного ряда.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM mart.abc_skus AS a
        LEFT JOIN mart.xyz_skus AS x USING (product_key)
        WHERE a.abc_class IS NOT NULL AND x.product_key IS NULL
    ) THEN
        RAISE EXCEPTION 'An ABC-classified product is missing in XYZ';
    END IF;
END;
$$;

-- 7. Сверка итоговой ABC-XYZ-витрины
-- с исходными витринами ABC и XYZ.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM mart.abc_skus AS a

        FULL OUTER JOIN mart.abc_xyz_skus AS m
            ON a.product_key = m.product_key

        LEFT JOIN mart.xyz_skus AS x
            ON a.product_key = x.product_key

        WHERE a.product_key IS NULL
           OR m.product_key IS NULL

           OR (
               a.product_name,
               a.sku_id,
               a.product_id,
               a.legacy_sku_key,
               a.order_items_count,
               a.orders_count,
               a.sold_quantity,
               a.sales_amount,
               a.abc_class,
               a.is_placeholder,
               a.exclusion_reason,
               x.first_sale_month,
               x.last_sale_month,
               x.months_with_sales,
               x.observation_months,
               x.avg_monthly_units,
               x.stddev_monthly_units,
               x.cv_pct,
               x.xyz_relative_class,
               x.xyz_status
           ) IS DISTINCT FROM (
               m.product_name,
               m.sku_id,
               m.product_id,
               m.legacy_sku_key,
               m.order_items_count,
               m.orders_count,
               m.sold_quantity,
               m.sales_amount,
               m.abc_class,
               m.is_placeholder,
               m.exclusion_reason,
               m.first_sale_month,
               m.last_sale_month,
               m.months_with_sales,
               m.observation_months,
               m.avg_monthly_units,
               m.stddev_monthly_units,
               m.cv_pct,
               m.xyz_relative_class,
               m.xyz_status
           )

           OR m.abc_xyz_class IS DISTINCT FROM
               CASE
                   WHEN a.abc_class IS NOT NULL
                    AND x.xyz_relative_class IS NOT NULL
                       THEN a.abc_class || x.xyz_relative_class
                   ELSE NULL
               END
    ) THEN
        RAISE EXCEPTION
            'ABC-XYZ reconciliation failed';
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
