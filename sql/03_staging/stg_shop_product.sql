-- Olenenka DWH
-- Подготовка справочника товаров для аналитики
-- Сохраняем все товары, включая скрытые и без категорий.
-- Каталог отражает состояние на момент выгрузки, а не всю историю.



DROP TABLE IF EXISTS staging.shop_product;


CREATE TABLE staging.shop_product AS
SELECT -- Идентификаторы
 id::BIGINT AS product_id,
 NULLIF(sku_id, '')::BIGINT AS main_sku_id,
 NULLIF(category_id, '')::BIGINT AS main_category_id, -- Информация о товаре
 name AS product_name,
 NULLIF(sku_type, '') AS sku_type,
 currency, -- Дата создания карточки
 create_datetime::TIMESTAMP AS created_at, -- Цены из текущего каталога.
 -- Для исторических продаж используем цены из заказов.
 NULLIF(price, '')::NUMERIC(20, 4) AS catalog_price,
 NULLIF(min_price, '')::NUMERIC(20, 4) AS min_price,
 NULLIF(max_price, '')::NUMERIC(20, 4) AS max_price, -- Остатки на момент выгрузки, не исторические остатки
 NULLIF(count, '')::NUMERIC(20, 4) AS stock_count, -- Состояние карточки
 status AS product_status,
 NULLIF(image_id, '')::BIGINT AS image_id, -- Признаки полноты карточки
 NULLIF(category_id, '') IS NOT NULL AS has_category,
                                        NULLIF(image_id, '') IS NOT NULL
AND image_id <> '0' AS has_main_image, -- Статус 1 соответствует опубликованной карточке
 status = '1' AS is_published
FROM raw.shop_product;


ALTER TABLE staging.shop_product ADD CONSTRAINT pk_staging_shop_product PRIMARY KEY (product_id);
