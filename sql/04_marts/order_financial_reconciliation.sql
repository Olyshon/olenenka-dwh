-- One row per completed order, including orders with no calculated items.
CREATE OR REPLACE VIEW mart.order_financial_reconciliation AS
WITH item_totals AS (
    SELECT order_id,
           COUNT(*) AS item_count,
           COUNT(item_amount_after_discount) AS calculated_item_count,
           SUM(item_amount_after_discount) AS calculated_amount
    FROM mart.fact_order_items_financial
    GROUP BY order_id
)
SELECT o.order_id,
       o.order_date,
       o.order_total,
       o.shipping,
       COALESCE(i.item_count, 0) AS item_count,
       COALESCE(i.calculated_item_count, 0) AS calculated_item_count,
       i.calculated_amount AS items_after_discount,
       o.order_total - o.shipping - i.calculated_amount AS residual_amount,
       CASE
           WHEN o.order_total IS NULL THEN 'missing_order_total'
           WHEN i.item_count IS NULL THEN 'no_items'
           WHEN i.calculated_item_count < i.item_count THEN 'incomplete'
           WHEN ABS(ROUND(o.order_total - o.shipping - i.calculated_amount, 4)) > 0.01 THEN 'mismatch'
           ELSE 'matched'
       END AS reconciliation_status
FROM mart.fact_orders AS o
LEFT JOIN item_totals AS i USING (order_id)
WHERE o.is_completed;
