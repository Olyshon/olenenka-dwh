-- Olenenka DWH
-- Продажи по SKU за 2013–2018 годы
-- Только завершённые заказы.
-- Технические карточки сохраняем, но отмечаем отдельно.


DROP TABLE IF EXISTS mart.sales_by_sku;

CREATE TABLE mart.sales_by_sku AS
WITH item_sales AS (
    SELECT
        CASE
            WHEN sku_id IS NOT NULL
                THEN 'sku:' || sku_id::TEXT
            WHEN legacy_sku_key IS NOT NULL
                THEN legacy_sku_key
            ELSE 'unidentified'
        END AS product_key,

        sku_id,
        product_id,
        legacy_sku_key,
        item_name,
        order_id,
        quantity,
        item_amount_before_discount,
        item_amount_after_discount

    FROM mart.fact_order_items
    WHERE is_completed
      AND order_date >= DATE '2013-01-01'
      AND order_date < DATE '2019-01-01'
)

SELECT
    i.product_key,

    -- Название товара для отображения
    COALESCE(
        p.product_name,
        l.product_name,
        MAX(i.item_name)
    ) AS product_name,

    -- Идентификаторы
    i.sku_id,
    i.product_id,
    i.legacy_sku_key,

    -- Продажи
    COUNT(*) AS order_items_count,
    COUNT(DISTINCT i.order_id) AS orders_count,
    SUM(i.quantity) AS sold_quantity,
    SUM(i.item_amount_before_discount) AS amount_before_discount,
    SUM(i.item_amount_after_discount) AS sales_amount,

    -- Признак технической карточки
    e.product_key IS NOT NULL AS is_placeholder

FROM item_sales AS i
LEFT JOIN mart.dim_products AS p
    ON i.product_id = p.product_id
LEFT JOIN mart.dim_legacy_skus AS l
    ON i.legacy_sku_key = l.legacy_sku_key
LEFT JOIN mart.product_exclusions AS e
    ON i.product_key = e.product_key

GROUP BY
    i.product_key,
    i.sku_id,
    i.product_id,
    i.legacy_sku_key,
    p.product_name,
    l.product_name,
    e.product_key;

ALTER TABLE mart.sales_by_sku
ADD CONSTRAINT pk_mart_sales_by_sku PRIMARY KEY (product_key);
