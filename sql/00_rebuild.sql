-- Olenenka DWH
-- Сценарий полной пересборки аналитического хранилища.
--
-- Назначение:
-- 1. Проверка исходных данных RAW.
-- 2. Пересоздание слоёв STAGING и MART.
-- 3. Выполнение проверок качества и целостности данных.
--
-- Требования:
-- - PostgreSQL 18.
-- - Предварительно загруженные таблицы RAW.
-- - Запуск через psql с параметром -v target_db=<имя_базы>.
--
-- Все преобразования и проверки выполняются в одной транзакции.
-- При ошибке изменения откатываются.

\set ON_ERROR_STOP on

-- Требуем явного указания целевой базы данных.
\if :{?target_db}
\else
    \echo 'ERROR: Target database is not specified'
    \quit 1
\endif

BEGIN ISOLATION LEVEL REPEATABLE READ;

-- Сохраняем указанное имя базы для проверки внутри транзакции.
SELECT set_config('olenenka.target_db', :'target_db', true);

DO $$
BEGIN
    -- Проверяем совпадение фактической и указанной базы.
    -- Исходная база olenenka_dwh защищена от пересборки.
    IF current_database() <> current_setting('olenenka.target_db')
       OR current_database() = 'olenenka_dwh'
    THEN
        RAISE EXCEPTION
            'Unsafe target database: %', current_database();
    END IF;
END
$$;
SELECT pg_advisory_xact_lock(4721082263);
\ir 02_data_quality/01_raw_contract.sql
\ir 04_marts/00_prepare_rebuild.sql
\ir 03_staging/stg_shop_category.sql
\ir 03_staging/stg_shop_category_products.sql
\ir 03_staging/stg_shop_order.sql
\ir 03_staging/stg_shop_order_items.sql
\ir 03_staging/stg_shop_product.sql
\ir 03_staging/stg_shop_product_skus.sql
\ir 02_data_quality/02_staging_reconciliation.sql
\ir 03_staging/stg_legacy_sku_mapping.sql
\ir 04_marts/dim_products.sql
\ir 04_marts/dim_skus.sql
\ir 04_marts/dim_legacy_skus.sql
\ir 04_marts/product_exclusions.sql
\ir 04_marts/fact_orders.sql
\ir 04_marts/fact_order_items.sql
\ir 04_marts/fact_order_items_financial.sql
\ir 04_marts/order_financial_reconciliation.sql
\ir 04_marts/sales_monthly.sql
\ir 04_marts/sales_by_sku.sql
\ir 04_marts/sku_sales_monthly.sql
\ir 04_marts/abc_skus.sql
\ir 04_marts/xyz_skus.sql
\ir 04_marts/abc_xyz_skus.sql
\ir 02_data_quality/03_mart_integrity.sql
\ir 02_data_quality/04_financial_reconciliation.sql
\ir 02_data_quality/05_bi_reconciliation.sql
\ir 02_data_quality/06_historical_snapshot.sql
COMMIT;
