DO $$
BEGIN
IF EXISTS (
        SELECT 1
        FROM mart.fact_order_items AS f
        JOIN mart.fact_orders AS o USING (order_id)
        WHERE o.is_completed
          AND (f.allocated_discount IS NULL OR f.item_amount_before_discount IS NULL
               OR f.item_amount_after_discount IS NULL
               OR f.item_amount_after_discount IS DISTINCT FROM
                  f.item_amount_before_discount - f.allocated_discount)
    ) THEN
        RAISE EXCEPTION 'A completed order has incomplete or inconsistent item calculations';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM mart.fact_orders AS o
        LEFT JOIN mart.fact_order_items AS f USING (order_id)
        WHERE o.is_completed
        GROUP BY o.order_id, o.discount
        HAVING o.discount IS NULL
            OR (COUNT(f.item_id) = 0 AND o.discount <> 0)
            OR (COUNT(f.item_id) > 0 AND
                (COUNT(f.allocated_discount) <> COUNT(f.item_id)
                 OR ABS(SUM(f.allocated_discount) - o.discount) > 0.01))
    ) THEN
        RAISE EXCEPTION 'Allocated discounts do not reconcile by completed order';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM mart.order_financial_reconciliation
        WHERE reconciliation_status IS NULL
           OR reconciliation_status NOT IN ('matched', 'mismatch', 'no_items')
           OR (reconciliation_status = 'no_items'
               AND NOT (order_total IS NOT DISTINCT FROM 0
                        AND shipping IS NOT DISTINCT FROM 0))
    ) THEN
        RAISE EXCEPTION 'Undocumented or incomplete completed order';
    END IF;
END
$$;
-- Independent comparison: original quantities/prices and order-level adjustments.
-- Use a tiny arithmetic tolerance for NUMERIC division in the allocation.
DO $$
BEGIN
    IF EXISTS (
        WITH raw_items AS (
            SELECT order_id::bigint AS order_id,
                   SUM((price::numeric * quantity::numeric)::numeric(20,4)) AS gross
            FROM raw.shop_order_items
            GROUP BY order_id::bigint
        ), expected AS (
            SELECT o.id::bigint AS order_id,
                   i.gross - COALESCE(NULLIF(o.discount, '')::numeric, 0) AS net,
                   COALESCE(NULLIF(o.shipping, '')::numeric, 0) AS shipping,
                   o.total::numeric AS order_total
            FROM raw.shop_order AS o
            JOIN raw_items AS i ON i.order_id = o.id::bigint
            WHERE o.state_id = 'completed'
              AND o.create_datetime::timestamp >= TIMESTAMP '2013-01-01'
              AND o.create_datetime::timestamp < TIMESTAMP '2019-01-01'
        ), actual AS (
            SELECT *
            FROM mart.order_financial_reconciliation
            WHERE order_date >= DATE '2013-01-01' AND order_date < DATE '2019-01-01'
        )
        SELECT 1
        FROM expected AS e FULL JOIN actual AS a USING (order_id)
        WHERE e.order_id IS NULL OR a.order_id IS NULL
           OR e.shipping IS DISTINCT FROM a.shipping
           OR e.order_total IS DISTINCT FROM a.order_total
           OR a.items_after_discount IS NULL
           OR ABS(e.net - a.items_after_discount) > 0.000001
           OR ABS(e.order_total - e.shipping - e.net - a.residual_amount) > 0.000001
           OR a.residual_amount IS NULL
           OR (ABS(e.order_total - e.shipping - e.net) > 0.01)
              IS DISTINCT FROM (a.reconciliation_status = 'mismatch')
    ) THEN
        RAISE EXCEPTION 'Financial view differs from independent RAW reconciliation';
    END IF;
END
$$;


-- Сумма скидок по заказу может совпасть при неверном распределении по позициям.
-- Проверяем долю каждой позиции независимо, используя исходные TEXT-значения RAW.
DO $$
BEGIN
    IF EXISTS (
        WITH source_items AS (
            SELECT id::BIGINT AS item_id, order_id::BIGINT AS order_id,
                   (price::NUMERIC * quantity::NUMERIC)::NUMERIC(20,4) AS gross
            FROM raw.shop_order_items
        ), expected AS (
            SELECT i.*, SUM(gross) OVER (PARTITION BY order_id) AS order_gross
            FROM source_items AS i
        )
        SELECT 1
        FROM expected AS e
        JOIN raw.shop_order AS o ON o.id::BIGINT = e.order_id
        JOIN mart.fact_order_items AS f USING (item_id)
        WHERE o.state_id = 'completed'
          AND (
              f.allocated_discount IS NULL
              OR ABS(f.allocated_discount -
                  CASE WHEN e.order_gross > 0
                       THEN COALESCE(NULLIF(o.discount, '')::NUMERIC, 0) * e.gross / e.order_gross
                       WHEN COALESCE(NULLIF(o.discount, '')::NUMERIC, 0) = 0 THEN 0::NUMERIC
                  END) > 0.000001
          )
    ) THEN
        RAISE EXCEPTION 'Item allocated discount differs from its RAW proportional share';
    END IF;
END;
$$;
