
-- Olenenka DWH
-- Исследование исторического ассортимента Webasyst.
--
-- Цель:
-- 1. Оценить полноту текущего каталога товаров и SKU.
-- 2. Исследовать исторические позиции с нулевыми ID.
-- 3. Проверить возможность идентификации по артикулам
--    и названиям товаров.
-- 4. Оценить результаты восстановления исторических SKU.
--
-- Особенности данных:
-- Текущий каталог Webasyst не содержит все товары,
-- которые присутствовали в исторических заказах.
-- Для восстановления используются прежние идентификаторы,
-- исторические артикулы и названия товарных позиций.
-- Неоднозначные исторические коды обрабатываются отдельно.


-- 1. Сравнение исторических идентификаторов с каталогом.
--
-- Считаем уникальные ID товаров и SKU в заказах.
-- Отдельно определяем положительные ID,
-- отсутствующие в текущих таблицах каталога.
-- Значения 0 и пустые строки не считаются
-- восстановимыми положительными идентификаторами.

SELECT
    COUNT(DISTINCT NULLIF(i.product_id, ''))
        AS historical_product_ids,

    COUNT(DISTINCT NULLIF(i.sku_id, ''))
        AS historical_sku_ids,

    COUNT(DISTINCT i.product_id) FILTER (
        WHERE p.id IS NULL
          AND NULLIF(i.product_id, '') IS NOT NULL
          AND i.product_id <> '0'
    ) AS missing_product_ids,

    COUNT(DISTINCT i.sku_id) FILTER (
        WHERE s.id IS NULL
          AND NULLIF(i.sku_id, '') IS NOT NULL
          AND i.sku_id <> '0'
    ) AS missing_sku_ids

FROM raw.shop_order_items AS i

LEFT JOIN raw.shop_product AS p
    ON i.product_id = p.id

LEFT JOIN raw.shop_product_skus AS s
    ON i.sku_id = s.id;


-- 2. Распределение позиций с product_id = 0 по годам.
--
-- Проверяем, как менялась доля исторических позиций
-- с нулевым идентификатором товара.

SELECT
    EXTRACT(YEAR FROM o.created_at)::INTEGER AS year,

    COUNT(*) AS total_items,

    COUNT(*) FILTER (
        WHERE i.product_id = 0
    ) AS zero_product_id_items,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE i.product_id = 0
        ) / NULLIF(COUNT(*), 0),
        1
    ) AS zero_product_id_pct

FROM staging.shop_order_items AS i

JOIN staging.shop_order AS o
    ON i.order_id = o.order_id

GROUP BY year
ORDER BY year;


-- 3. Исследование артикулов у позиций с нулевыми ID.
--
-- В исторических заказах артикул иногда сохранялся
-- в отдельном поле sku_code или в начале названия:
-- [АРТИКУЛ] Название товара.
--
-- Проверяем, какая часть позиций допускает
-- идентификацию по этим признакам.

SELECT
    COUNT(*) AS total_items,

    COUNT(*) FILTER (
        WHERE NULLIF(TRIM(sku_code), '') IS NOT NULL
    ) AS items_with_sku_code,

    COUNT(*) FILTER (
        WHERE item_name ~ '^\[[^]]+\]'
    ) AS items_with_code_in_name,

    COUNT(DISTINCT SUBSTRING(
        item_name FROM '^\[([^]]+)\]'
    )) AS distinct_codes_in_names,

    COUNT(*) FILTER (
        WHERE item_name !~ '^\[[^]]+\]'
    ) AS items_without_code_in_name

FROM staging.shop_order_items

WHERE product_id = 0
  AND sku_id = 0;


-- 4. Результаты восстановления исторических SKU.
--
-- Подсчитываем восстановленные исторические группы
-- и группы с неоднозначными артикулами.

SELECT
    COUNT(*) AS historical_groups,

    COUNT(*) FILTER (
        WHERE has_ambiguous_code
    ) AS ambiguous_groups

FROM mart.dim_legacy_skus;


-- Результаты исследования:
-- В историческом справочнике сформировано 878 групп.
--
-- Вывод:
-- Текущего каталога Webasyst недостаточно
-- для идентификации всех исторических продаж.
--
-- Для позиций с утраченными положительными ID
-- используются исторические идентификаторы.
-- Для позиций с нулевыми ID дополнительно
-- анализируются артикулы и названия товаров.
--
-- Неоднозначные коды учитываются при восстановлении,
-- чтобы не объединять различные товары ошибочно.
--
-- Подробная логика восстановления реализована
-- в STAGING и справочнике mart.dim_legacy_skus.
