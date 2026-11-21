
-- Olenenka DWH
-- Помесячные продажи по товарным группам за 2013–2018 годы.
--
-- Назначение:
-- 1. Анализ динамики продаж отдельных SKU.
-- 2. Подготовка данных для XYZ-анализа.
-- 3. Использование помесячных показателей в BI.
--
-- Гранулярность: одна товарная группа × один месяц
-- с зафиксированными позициями завершённых заказов.
--
-- Отсутствующие месяцы не заполняются нулями.
-- Для XYZ календарные месяцы будут восстановлены отдельно.
-- Технические и неопознанные группы сохраняются.

DROP TABLE IF EXISTS mart.sku_sales_monthly;

CREATE TABLE mart.sku_sales_monthly AS
SELECT
    CASE
        WHEN sku_id IS NOT NULL
            THEN 'sku:' || sku_id::TEXT
        ELSE COALESCE(legacy_sku_key, 'unidentified')
    END AS product_key,

    order_month,

    COUNT(*) AS order_items_count,
    COUNT(DISTINCT order_id) AS orders_count,
    SUM(quantity) AS sold_quantity,

    SUM(item_amount_before_discount)
        AS amount_before_discount,

    SUM(item_amount_after_discount)
        AS sales_amount

FROM mart.fact_order_items

WHERE is_completed
  AND order_date >= DATE '2013-01-01'
  AND order_date < DATE '2019-01-01'

GROUP BY 1, 2;

ALTER TABLE mart.sku_sales_monthly
    ADD CONSTRAINT pk_mart_sku_sales_monthly
    PRIMARY KEY (product_key, order_month);

CREATE INDEX idx_mart_sku_sales_monthly_month
    ON mart.sku_sales_monthly (order_month);
