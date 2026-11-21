
-- Olenenka DWH
-- Подготовка слоя MART к повторной пересборке.
--
-- Удаляем финансовые представления до пересоздания
-- таблиц, от которых они зависят.
--
-- Учитываем прежнюю структуру проекта:
-- fact_order_items_financial ранее был таблицей,
-- а в текущей версии является представлением.
--
-- Остальные таблицы MART пересоздаются
-- в соответствующих SQL-модулях.

DROP VIEW IF EXISTS mart.order_financial_reconciliation;


-- Удаляем финансовый объект с учётом его типа.

DO $$
DECLARE
    kind "char";
BEGIN
    SELECT relkind
    INTO kind
    FROM pg_class
    WHERE oid = to_regclass('mart.fact_order_items_financial');

    IF kind = 'v' THEN
        DROP VIEW mart.fact_order_items_financial;

    ELSIF kind = 'r' THEN
        DROP TABLE mart.fact_order_items_financial;

    ELSIF kind IS NOT NULL THEN
        RAISE EXCEPTION
            'Unexpected financial relation type';
    END IF;
END;
$$;

