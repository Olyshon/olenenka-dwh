-- Olenenka DWH
-- Факты заказов Webasyst
-- Одна строка — один заказ.
-- Сохраняем все статусы, не только завершённые.


DROP TABLE IF EXISTS mart.fact_orders;

CREATE TABLE mart.fact_orders AS
SELECT
    -- Идентификаторы
    order_id,
    contact_id,

    -- Даты
    created_at,
    created_at::DATE AS order_date,
    DATE_TRUNC('month', created_at)::DATE AS order_month,
    paid_at,

    -- Статус и признаки заказа
    order_status,
    is_completed,
    has_paid_date,
    is_offline_service_account,

    -- Финансовые показатели
    order_total,
    COALESCE(discount, 0) AS discount,
    COALESCE(shipping, 0) AS shipping,
    COALESCE(tax, 0) AS tax,
    currency,

    -- Сумму завершённых заказов считаем отдельно.
    -- Это не подтверждённая чистая выручка магазина.
    CASE
        WHEN is_completed THEN order_total
        ELSE 0
    END AS completed_order_amount

FROM staging.shop_order;

ALTER TABLE mart.fact_orders
ADD CONSTRAINT pk_mart_fact_orders PRIMARY KEY (order_id);
