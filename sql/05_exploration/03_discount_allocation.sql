
-- Olenenka DWH
-- Исследование скидок и финансовой согласованности заказов.
--
-- Цель:
-- 1. Изучить скидки на уровне заказа и товарных позиций.
-- 2. Сравнить суммы скидок на разных уровнях.
-- 3. Проверить финансовые расхождения после распределения скидок.
--
-- Особенности данных:
-- Скидка товарной позиции может уже учитываться
-- в общей скидке заказа.
-- Поэтому нельзя автоматически суммировать эти показатели.
--
-- В финансовой модели скидка заказа распределяется
-- пропорционально стоимости товарных позиций.
-- Поле total_discount переносится из исходных данных Webasyst.
-- Его точная семантика в исторических заказах не подтверждена.
-- Поэтому скидки заказа и товарных позиций сравниваются,
-- но не суммируются автоматически.


-- 1. Наличие скидок на уровне заказа и товарных позиций.
--
-- Исследуем все заказы, представленные в MART.
-- Считаем заказы со скидкой заказа, скидками позиций
-- и одновременным наличием обоих признаков.

WITH item_discounts AS (
    SELECT
        order_id,
        SUM(COALESCE(total_discount, 0)) AS items_discount
    FROM mart.fact_order_items
    GROUP BY order_id
)

SELECT
    COUNT(*) AS total_orders,

    COUNT(*) FILTER (
        WHERE o.discount > 0
    ) AS orders_with_discount,

    COUNT(*) FILTER (
        WHERE COALESCE(i.items_discount, 0) > 0
    ) AS orders_with_item_discount,

    COUNT(*) FILTER (
        WHERE o.discount > 0
          AND COALESCE(i.items_discount, 0) > 0
    ) AS orders_with_both_discounts,

    SUM(o.discount) AS total_order_discount,
    SUM(COALESCE(i.items_discount, 0)) AS total_items_discount

FROM mart.fact_orders AS o
LEFT JOIN item_discounts AS i
    ON o.order_id = i.order_id;


-- 2. Сравнение скидок заказа и товарных позиций.
--
-- Проверяем, совпадают ли суммы скидок
-- на двух уровнях с точностью до одной копейки.
-- Отбираем заказы с положительной суммой скидок позиций.

WITH item_discounts AS (
    SELECT
        order_id,
        SUM(COALESCE(total_discount, 0)) AS items_discount
    FROM mart.fact_order_items
    GROUP BY order_id
)

SELECT
    COUNT(*) AS orders_count,

    COUNT(*) FILTER (
        WHERE ABS(o.discount - i.items_discount) <= 0.01
    ) AS equal_discounts,

    COUNT(*) FILTER (
        WHERE o.discount > i.items_discount + 0.01
    ) AS order_discount_greater,

    COUNT(*) FILTER (
        WHERE i.items_discount > o.discount + 0.01
    ) AS items_discount_greater,

    SUM(o.discount) AS order_discount_sum,
    SUM(i.items_discount) AS items_discount_sum

FROM mart.fact_orders AS o
JOIN item_discounts AS i
    ON o.order_id = i.order_id

WHERE i.items_discount > 0;


-- 3. Финансовая сверка заказов за 2013–2018 годы.
--
-- Сопоставляем суммы товарных позиций после скидок,
-- доставку и итог заказа.
-- Остаточное расхождение отражает исторические
-- особенности исходных финансовых данных.

SELECT
    reconciliation_status,
    COUNT(*) AS orders,

    ROUND(
        SUM(items_after_discount), 3
    ) AS item_net,

    ROUND(
        SUM(shipping), 3
    ) AS shipping,

    ROUND(
        SUM(residual_amount), 3
    ) AS residual,

    SUM(order_total) AS order_total

FROM mart.order_financial_reconciliation

WHERE order_date >= DATE '2013-01-01'
  AND order_date < DATE '2019-01-01'

GROUP BY reconciliation_status
ORDER BY reconciliation_status;


-- Результаты исследования:
-- В исторических данных выявлены 13 заказов
-- с финансовыми расхождениями свыше 0,01 ₽.
--
-- Вывод:
-- Скидки заказа и товарных позиций нельзя
-- интерпретировать как независимые величины
-- без проверки правил Webasyst.
--
-- Распределение скидки заказа выполняется
-- пропорционально стоимости товарных позиций.
-- Исходные скидки позиций сохраняются.
--
-- Исторические финансовые исключения учитываются
-- отдельно и не скрываются искусственной корректировкой сумм.
