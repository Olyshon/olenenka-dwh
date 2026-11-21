-- Olenenka DWH
-- Товарные позиции заказов
-- Одна строка — одна позиция заказа.
-- Сохраняем все позиции, включая старые с нулевыми ID.


DROP TABLE IF EXISTS mart.fact_order_items;

CREATE TABLE mart.fact_order_items AS
WITH items AS (
SELECT
    -- Идентификаторы
    i.item_id,
    i.order_id,
    NULLIF(i.product_id, 0) AS product_id,
    NULLIF(i.sku_id, 0) AS sku_id,
    l.legacy_sku_key,

    -- Название и артикул на момент заказа
    i.item_name,
    i.sku_code,
    i.item_type,

    -- Количество и цены
    i.quantity,
    i.unit_price,
    i.total_discount,
    i.item_amount_before_discount,
    i.purchase_price,
    i.has_known_purchase_price,
    i.has_positive_quantity,

    -- Данные заказа
    o.order_date,
    o.order_month,
    o.order_status,
    o.is_completed,
    o.is_offline_service_account

FROM staging.shop_order_items AS i
JOIN mart.fact_orders AS o
    ON i.order_id = o.order_id
LEFT JOIN staging.legacy_sku_mapping AS l
    ON i.item_id = l.item_id
), totals AS (
    SELECT i.*, SUM(item_amount_before_discount) OVER (PARTITION BY order_id) AS items_total
    FROM items AS i
), allocated AS (
    SELECT t.*,
           CASE WHEN t.items_total > 0 THEN o.discount * t.item_amount_before_discount / t.items_total
                WHEN o.discount = 0 THEN 0::numeric END AS allocated_discount,
           ABS(t.items_total - o.discount + o.shipping - o.order_total) > 0.01 AS has_amount_mismatch
    FROM totals AS t JOIN mart.fact_orders AS o USING (order_id)
)
SELECT item_id, order_id, product_id, sku_id, legacy_sku_key, item_name,
       sku_code, item_type, quantity, unit_price, total_discount,
       item_amount_before_discount, purchase_price, has_known_purchase_price,
       has_positive_quantity, order_date, order_month, order_status, is_completed,
       is_offline_service_account, allocated_discount,
       item_amount_before_discount - allocated_discount AS item_amount_after_discount,
       has_amount_mismatch
FROM allocated;
ALTER TABLE mart.fact_order_items ADD PRIMARY KEY (item_id);
