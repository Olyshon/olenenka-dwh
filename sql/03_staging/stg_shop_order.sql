-- Olenenka DWH
-- Подготовка заказов для аналитики
-- Преобразуем типы данных и добавляем признаки для дальнейшего анализа.
-- Исходную таблицу raw.shop_order не изменяем.

-- Пересоздаём staging-таблицу из исходных данных.
-- При повторном запуске текущая таблица заменяется.

DROP TABLE IF EXISTS staging.shop_order;


CREATE TABLE staging.shop_order AS
SELECT -- Идентификаторы
 id::BIGINT AS order_id,
 NULLIF(contact_id, '')::BIGINT AS contact_id,
 NULLIF(assigned_contact_id, '')::BIGINT AS assigned_contact_id, -- Даты
 create_datetime::TIMESTAMP AS created_at,
 NULLIF(update_datetime, '')::TIMESTAMP AS updated_at,
 NULLIF(paid_date, '')::DATE AS paid_at, -- Статус и денежные показатели
 state_id AS order_status,
 total::NUMERIC(20, 4) AS order_total,
 NULLIF(discount, '')::NUMERIC(20, 4) AS discount,
 NULLIF(shipping, '')::NUMERIC(20, 4) AS shipping,
 NULLIF(tax, '')::NUMERIC(20, 4) AS tax,
 currency,
 NULLIF(rate, '')::NUMERIC(20, 8) AS currency_rate, -- Исходные календарные поля (в них обнаружены ошибки)
 NULLIF(paid_year, '')::INTEGER AS paid_year_raw,
 NULLIF(paid_month, '')::INTEGER AS paid_month_raw,
 NULLIF(paid_quarter, '')::INTEGER AS paid_quarter_raw, -- Год, месяц и квартал пересчитываем из даты оплаты
 EXTRACT(YEAR
         FROM NULLIF(paid_date, '')::DATE)::INTEGER AS paid_year,
 EXTRACT(MONTH
         FROM NULLIF(paid_date, '')::DATE)::INTEGER AS paid_month,
 EXTRACT(QUARTER
         FROM NULLIF(paid_date, '')::DATE)::INTEGER AS paid_quarter, -- Служебные аккаунты 2263 и 4669 использовались для офлайн-продаж.
 -- completed означает, что заказ получен покупателем.
 -- paid_date — дата оплаты, а не получения заказа.
 COALESCE(NULLIF(contact_id, '')::BIGINT IN (2263, 4669), FALSE) AS is_offline_service_account,
               state_id = 'completed' AS is_completed,
               NULLIF(paid_date, '') IS NOT NULL AS has_paid_date,
                                                    NULLIF(is_first, '')::INTEGER AS is_first_raw, -- Проверяем, совпадают ли исходные месяц и квартал
 -- с рассчитанными по дате оплаты.
 CASE
     WHEN NULLIF(paid_date, '') IS NOT NULL
          AND (NULLIF(paid_month, '')::INTEGER IS DISTINCT
               FROM EXTRACT(MONTH
                            FROM paid_date::DATE)::INTEGER
               OR NULLIF(paid_quarter, '')::INTEGER IS DISTINCT
               FROM EXTRACT(QUARTER
                            FROM paid_date::DATE)::INTEGER) THEN TRUE
     ELSE FALSE
 END AS has_calendar_mismatch
FROM raw.shop_order;

-- Первичный ключ гарантирует уникальность order_id.

ALTER TABLE staging.shop_order ADD CONSTRAINT pk_staging_shop_order PRIMARY KEY (order_id);
