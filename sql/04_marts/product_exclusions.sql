-- Olenenka DWH
-- Справочник технических товарных карточек
-- Исключаем из товарных рейтингов, но сохраняем в общем обороте.
-- Добавляем только подтверждённые случаи.


DROP TABLE IF EXISTS mart.product_exclusions;

CREATE TABLE mart.product_exclusions (
    product_key TEXT PRIMARY KEY,
    exclusion_reason TEXT NOT NULL,
    is_confirmed BOOLEAN NOT NULL DEFAULT TRUE
);

-- Универсальная карточка "РАЗНОЕ / Рондель Китай"
INSERT INTO mart.product_exclusions (
    product_key,
    exclusion_reason
)
VALUES (
    'sku:1021',
    'Универсальная карточка для продажи разных товаров'
);

-- Историческая карточка raznoe1:
-- палочки для бусин, не заведённые в каталог
INSERT INTO mart.product_exclusions (
    product_key,
    exclusion_reason
)
SELECT
    legacy_sku_key,
    'Техническая карточка для товаров вне каталога'
FROM mart.dim_legacy_skus
WHERE LOWER(historical_sku) = 'raznoe1';
