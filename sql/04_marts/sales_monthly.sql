-- Olenenka DWH
-- Месячная динамика завершённых заказов Webasyst, 2013–2018.
-- Разделяем известные служебные аккаунты и остальные заказы.
-- Остальные заказы не обязательно являются интернет-продажами.


DROP TABLE IF EXISTS mart.sales_monthly;


CREATE TABLE mart.sales_monthly AS
SELECT order_month, -- Все завершённые заказы
 COUNT(*) AS completed_orders,
 SUM(order_total) AS completed_amount,
 ROUND(AVG(order_total), 2) AS avg_order_total, -- Заказы двух известных служебных аккаунтов
 COUNT(*) FILTER (
                  WHERE is_offline_service_account) AS known_offline_orders,
 COALESCE(SUM(order_total) FILTER (
                                   WHERE is_offline_service_account), 0) AS known_offline_amount, -- Остальные заказы, канал продажи не подтверждён
 COUNT(*) FILTER (
                  WHERE is_offline_service_account IS NOT TRUE) AS other_orders,
 COALESCE(SUM(order_total) FILTER (
                                   WHERE is_offline_service_account IS NOT TRUE), 0) AS other_amount
FROM mart.fact_orders
WHERE is_completed
    AND order_date >= DATE '2013-01-01'
    AND order_date < DATE '2019-01-01'
GROUP BY order_month;


ALTER TABLE mart.sales_monthly ADD CONSTRAINT pk_mart_sales_monthly PRIMARY KEY (order_month);
