
-- Olenenka DWH
-- Относительная XYZ-классификация товарных групп.
-- Период: 2013–2018 годы.
--
-- Анализируется стабильность зафиксированных продаж,
-- а не истинного спроса: история складских остатков
-- за каждый месяц недоступна.
--
-- Методика:
-- 1. Интервал: от первой до последней положительной продажи.
-- 2. Промежуточные месяцы без продаж заполняются нулями.
-- 3. Метрика: количество проданных единиц.
-- 4. Минимальный интервал наблюдения: 12 месяцев.
-- 5. Относительные классы X/Y/Z определяются
--    по терцилям коэффициента вариации (CV).
--
-- Класс X означает относительно меньшую вариативность
-- внутри ассортимента, но не гарантирует стабильный спрос.

DROP TABLE IF EXISTS mart.xyz_skus;

CREATE TABLE mart.xyz_skus AS
WITH monthly_sales AS (
    SELECT
        product_key,
        order_month,
        sold_quantity
    FROM mart.sku_sales_monthly
),

history AS (
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
    LEFT JOIN monthly_sales AS m
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
    LEFT JOIN monthly_sales AS m
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

classified AS (
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

SELECT
    product_key,
    first_sale_month,
    last_sale_month,
    months_with_sales,
    observation_months,
    avg_monthly_units,
    stddev_monthly_units,
    cv_pct,
    xyz_relative_class,
    xyz_status
FROM classified;

ALTER TABLE mart.xyz_skus
    ADD CONSTRAINT pk_mart_xyz_skus
    PRIMARY KEY (product_key);
