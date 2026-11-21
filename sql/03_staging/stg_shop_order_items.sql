-- Olenenka DWH
-- Подготовка товарных позиций заказов для аналитики
-- Преобразуем типы данных, рассчитываем стоимость позиций
-- и отмечаем ограничения исходных данных.


-- Пересоздаём таблицу из исходных данных.

DROP TABLE IF EXISTS staging.shop_order_items;


CREATE TABLE staging.shop_order_items AS
SELECT -- Идентификаторы
 id::BIGINT AS item_id,
 order_id::BIGINT AS order_id,
 NULLIF(product_id, '')::BIGINT AS product_id,
 NULLIF(sku_id, '')::BIGINT AS sku_id,
 NULLIF(parent_id, '') AS parent_id,
 NULLIF(stock_id, '') AS stock_id, -- Информация о товарной позиции
 name AS item_name,
 sku_code,
 type AS item_type,
         NULLIF(service_id, '') AS service_id,
         NULLIF(service_variant_id, '') AS service_variant_id, -- Количество, цены и скидка
 price::NUMERIC(20, 4) AS unit_price,
 quantity::NUMERIC(20, 4) AS quantity,
 NULLIF(total_discount, '')::NUMERIC(20, 4) AS total_discount,
 NULLIF(purchase_price, '')::NUMERIC(20, 4) AS purchase_price, -- Стоимость позиции до скидок
 (price::NUMERIC * quantity::NUMERIC)::NUMERIC(20, 4) AS item_amount_before_discount, -- Три позиции имеют нулевое количество.
 -- Сохраняем их, но добавляем признак для фильтрации.
 quantity::NUMERIC > 0 AS has_positive_quantity, -- Нулевая закупочная цена не считается известной себестоимостью.
 NULLIF(purchase_price, '')::NUMERIC > 0 AS has_known_purchase_price
FROM raw.shop_order_items;

-- Проверяем уникальность идентификаторов товарных позиций.

ALTER TABLE staging.shop_order_items ADD CONSTRAINT pk_staging_shop_order_items PRIMARY KEY (item_id);
