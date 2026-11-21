
-- Olenenka DWH
-- Исследование ассортимента и результатов ABC-анализа.
-- Период: 2013–2018 годы, завершённые заказы.
--
-- Цель:
-- 1. Исследовать содержимое технических карточек.
-- 2. Оценить распределение товарных групп по ABC-классам.
-- 3. Посмотреть товары с наибольшим оборотом.


-- 1. Детализация технических карточек.
--
-- Одна техническая карточка могла использоваться
-- для продажи разных товаров.
-- Поэтому её оборот нельзя приписывать одному SKU.

SELECT
    CASE
        WHEN f.sku_id = 1021
            THEN 'sku:1021'
        ELSE 'legacy:raznoe1'
    END AS technical_group,

    f.item_name,
    COUNT(*) AS order_items_count,
    SUM(f.quantity) AS sold_quantity,
    ROUND(SUM(f.item_amount_after_discount), 2) AS sales_amount

FROM mart.fact_order_items_financial AS f

LEFT JOIN mart.dim_legacy_skus AS l
    ON f.legacy_sku_key = l.legacy_sku_key

WHERE f.is_completed
  AND f.order_date >= DATE '2013-01-01'
  AND f.order_date < DATE '2019-01-01'
  AND (
      f.sku_id = 1021
      OR LOWER(l.historical_sku) = 'raznoe1'
  )

GROUP BY technical_group, f.item_name
ORDER BY technical_group, sold_quantity DESC;


-- 2. Распределение товарных групп по ABC-классам.
--
-- Исключённые группы сохраняются в финансовых итогах,
-- но не участвуют в расчёте ABC.

SELECT
    COALESCE(abc_class, 'EXCLUDED') AS abc_class,
    COUNT(*) AS sku_groups,

    ROUND(SUM(sales_amount), 2) AS sales_amount,

    ROUND(
        100.0 * SUM(sales_amount)
        / SUM(SUM(sales_amount)) OVER (),
        2
    ) AS share_of_total_sales_pct

FROM mart.abc_skus
GROUP BY COALESCE(abc_class, 'EXCLUDED')
ORDER BY abc_class;


-- 3. TOP-20 товарных групп по обороту.
-- Технические и неопознанные группы исключены.

SELECT
    product_key,
    product_name,
    sold_quantity,
    ROUND(sales_amount, 2) AS sales_amount,
    abc_class

FROM mart.abc_skus

WHERE abc_class IS NOT NULL

ORDER BY sales_amount DESC, product_key
LIMIT 20;
