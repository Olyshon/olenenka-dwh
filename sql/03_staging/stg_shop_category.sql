-- Olenenka DWH
-- Подготовка справочника категорий товаров
-- Сохраняем иерархию и статусы категорий.



DROP TABLE IF EXISTS staging.shop_category;


CREATE TABLE staging.shop_category AS
SELECT -- Идентификаторы и иерархия
 id::BIGINT AS category_id,
 NULLIF(NULLIF(parent_id, ''), '0')::BIGINT AS parent_category_id,
 NULLIF(depth, '')::INTEGER AS depth,
 NULLIF(left_key, '')::INTEGER AS left_key,
 NULLIF(right_key, '')::INTEGER AS right_key, -- Название и адрес категории
 name AS category_name,
 NULLIF(url, '') AS category_url,
 NULLIF(full_url, '') AS full_url, -- Состояние категории
 status AS category_status, -- Признак корневой категории
 parent_id IS NULL
OR parent_id IN ('',
                 '0') AS is_root_category
FROM raw.shop_category;


ALTER TABLE staging.shop_category ADD CONSTRAINT pk_staging_shop_category PRIMARY KEY (category_id);
