-- Olenenka DWH
-- Подготовка справочника SKU для аналитики
-- Сохраняем все модификации товаров, включая SKU без артикула.
-- Цены и остатки отражают состояние каталога на момент выгрузки.



DROP TABLE IF EXISTS staging.shop_product_skus;


CREATE TABLE staging.shop_product_skus AS
SELECT -- Идентификаторы
 id::BIGINT AS sku_id,
 product_id::BIGINT AS product_id, -- Артикул и название модификации
 NULLIF(sku, '') AS sku_code,
 NULLIF(name, '') AS sku_name,
 NULLIF(id_1c, '') AS external_id, -- Цены из текущего каталога
 NULLIF(price, '')::NUMERIC(20, 4) AS catalog_price,
 NULLIF(purchase_price, '')::NUMERIC(20, 4) AS catalog_purchase_price, -- Остаток на момент выгрузки
 NULLIF(count, '')::NUMERIC(20, 4) AS stock_count, -- Доступность и порядок отображения
 available AS availability_raw,
 NULLIF(
        sort, '') AS sort_order_raw, -- Признаки для дальнейшей аналитики
 NULLIF(sku, '') IS NOT NULL AS has_sku_code,
                                NULLIF(purchase_price, '')::NUMERIC > 0 AS has_known_purchase_price
FROM raw.shop_product_skus;


ALTER TABLE staging.shop_product_skus ADD CONSTRAINT pk_staging_shop_product_skus PRIMARY KEY (sku_id);
