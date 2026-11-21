
-- Olenenka DWH
-- Итоговая витрина ABC-XYZ-анализа ассортимента.
-- Период: 2013–2018 годы.
--
-- Назначение:
-- Объединение финансовой значимости товарных групп (ABC)
-- и относительной регулярности продаж (XYZ).
--
-- Гранулярность: одна строка на product_key.
--
-- Классы XYZ определены относительно распределения CV
-- среди товаров с историей наблюдения от 12 месяцев.
-- X не означает стабильный спрос в абсолютном смысле.
--
-- Товары с недостаточной историей сохраняются без XYZ-класса.
-- Технические и неопознанные группы сохраняются без ABC/XYZ.
-- Значения NULL не заменяются на фиктивные классы.

DROP TABLE IF EXISTS mart.abc_xyz_skus;

CREATE TABLE mart.abc_xyz_skus AS
SELECT
    a.product_key,
    a.product_name,
    a.sku_id,
    a.product_id,
    a.legacy_sku_key,

    -- Показатели продаж за весь период.
    a.order_items_count,
    a.orders_count,
    a.sold_quantity,
    a.sales_amount,

    -- ABC: финансовая значимость.
    a.abc_class,
    a.is_placeholder,
    a.exclusion_reason,

    -- XYZ: история и вариативность продаж.
    x.first_sale_month,
    x.last_sale_month,
    x.months_with_sales,
    x.observation_months,
    x.avg_monthly_units,
    x.stddev_monthly_units,
    x.cv_pct,
    x.xyz_relative_class,
    x.xyz_status,

    -- Комбинация классов только для товаров,
    -- имеющих обе классификации.
    CASE
        WHEN a.abc_class IS NOT NULL
         AND x.xyz_relative_class IS NOT NULL
            THEN a.abc_class || x.xyz_relative_class
        ELSE NULL
    END AS abc_xyz_class

FROM mart.abc_skus AS a
LEFT JOIN mart.xyz_skus AS x
    ON a.product_key = x.product_key;

ALTER TABLE mart.abc_xyz_skus
    ADD CONSTRAINT pk_mart_abc_xyz_skus
    PRIMARY KEY (product_key);

CREATE INDEX idx_mart_abc_xyz_class
    ON mart.abc_xyz_skus (abc_xyz_class);
