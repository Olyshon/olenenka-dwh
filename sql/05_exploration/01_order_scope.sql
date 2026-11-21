
-- Olenenka DWH
-- Исследование заказов Webasyst и границ анализируемых данных.
--
-- Цель:
-- 1. Изучить статусы заказов и наличие даты оплаты.
-- 2. Выявить заказы известных сервисных аккаунтов офлайн-магазина.
-- 3. Проверить состав завершённых заказов за 2013–2018 годы.
--
-- Ограничения:
-- Статус completed означает завершение заказа,
-- но не обязательно совпадает с датой поступления оплаты.
-- Сервисные аккаунты 2263 и 4669 позволяют выделить
-- известные офлайн-продажи.
-- Остальные заказы нельзя автоматически считать онлайн-продажами.
-- После перехода части операций в МойСклад
-- Webasyst не отражает все офлайн-продажи.


-- 1. Распределение заказов по статусам.
-- Исследуем исходные статусы Webasyst.

SELECT
    state_id,
    COUNT(*) AS orders_count
FROM raw.shop_order
GROUP BY state_id
ORDER BY orders_count DESC;


-- 2. Заказы с заполненной датой оплаты.
-- Наличие paid_date не гарантирует статус completed.

SELECT
    state_id,
    COUNT(*) AS orders_with_paid_date,
    SUM(total::NUMERIC) AS total_with_paid_date
FROM raw.shop_order
WHERE paid_date IS NOT NULL
  AND paid_date <> ''
GROUP BY state_id
ORDER BY orders_with_paid_date DESC;


-- 3. Известные офлайн-заказы и остальные заказы.
-- Группировка по году создания заказа.
-- Используем RAW для исследования исходных идентификаторов.

SELECT
    EXTRACT(YEAR FROM create_datetime::TIMESTAMP)::INT
        AS order_year,

    CASE
        WHEN contact_id IN ('2263', '4669')
            THEN 'Known Offline'
        ELSE 'Other / Unclassified'
    END AS sales_channel,

    COUNT(*) AS orders_count

FROM raw.shop_order
WHERE state_id = 'completed'

GROUP BY order_year, sales_channel
ORDER BY order_year, sales_channel;


-- 4. Контроль состава завершённых заказов за 2013–2018 годы.
-- Период определяется датой создания заказа.
-- Заказы без contact_id включаются в прочие,
-- а не автоматически относятся к онлайн-продажам.

SELECT
    COUNT(*) AS completed_orders,
    ROUND(SUM(order_total), 2) AS completed_amount,

    COUNT(*) FILTER (
        WHERE contact_id IS NULL
    ) AS orders_without_contact,

    ROUND(
        COALESCE(
            SUM(order_total) FILTER (
                WHERE contact_id IS NULL
            ), 0
        ),
        2
    ) AS amount_without_contact

FROM mart.fact_orders
WHERE is_completed
  AND order_date >= DATE '2013-01-01'
  AND order_date < DATE '2019-01-01';


-- Результат исследования:
-- 10 420 завершённых заказов за 2013–2018 годы.
-- Из них 3 заказа без contact_id на сумму 1 832 ₽.
--
-- Вывод:
-- Для финансовой аналитики используется статус completed
-- и дата создания заказа.
-- Известные офлайн-заказы выделяются по сервисным аккаунтам.
-- Остальные заказы относятся к категории Other / Unclassified.
-- Полнота офлайн-продаж ограничена историей Webasyst.
