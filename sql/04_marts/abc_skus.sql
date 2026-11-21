
-- Olenenka DWH
-- ABC-классификация товарных групп за 2013–2018 годы.
-- Основа: завершённые заказы, товарный оборот после скидок.
-- A: ~80% оборота, B: следующие ~15%, C: оставшиеся ~5%.
--
-- Товары с одинаковым оборотом получают один ABC-класс.
-- Группа, пересекающая порог, остаётся в предыдущем классе.
-- Технические и неопознанные товары сохраняются без ABC-класса.

DROP TABLE IF EXISTS mart.abc_skus;

CREATE TABLE mart.abc_skus AS
WITH eligible AS (
    SELECT
        product_key,
        sales_amount
    FROM mart.sales_by_sku
    WHERE is_placeholder IS FALSE
      AND product_key <> 'unidentified'
      AND sales_amount > 0
),

-- Объединяем товары с одинаковым оборотом,
-- чтобы не разделять их между ABC-классами.
amount_groups AS (
    SELECT
        sales_amount,
        SUM(sales_amount) AS group_sales
    FROM eligible
    GROUP BY sales_amount
),

-- Рассчитываем накопленный оборот групп.
ranked_groups AS (
    SELECT
        sales_amount,
        group_sales,
        SUM(group_sales) OVER (
            ORDER BY sales_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_sales,
        SUM(group_sales) OVER () AS total_sales
    FROM amount_groups
),

-- Присваиваем класс на уровне группы одинакового оборота.
classified_groups AS (
    SELECT
        sales_amount,
        CASE
            WHEN (cumulative_sales - group_sales) / total_sales < 0.80
                THEN 'A'
            WHEN (cumulative_sales - group_sales) / total_sales < 0.95
                THEN 'B'
            ELSE 'C'
        END AS abc_class
    FROM ranked_groups
),

classified AS (
    SELECT
        e.product_key,
        c.abc_class
    FROM eligible AS e
    JOIN classified_groups AS c
        ON e.sales_amount = c.sales_amount
)

-- Сохраняем все товарные группы,
-- включая исключённые из ABC-классификации.
SELECT
    s.product_key,
    s.product_name,
    s.sku_id,
    s.product_id,
    s.legacy_sku_key,
    s.order_items_count,
    s.orders_count,
    s.sold_quantity,
    s.sales_amount,
    s.is_placeholder,
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
LEFT JOIN classified AS c
    ON s.product_key = c.product_key;

ALTER TABLE mart.abc_skus
    ADD CONSTRAINT pk_mart_abc_skus
    PRIMARY KEY (product_key);

