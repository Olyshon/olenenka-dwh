-- Read-only compatibility interface for existing SELECT queries.
CREATE VIEW mart.fact_order_items_financial AS
SELECT item_id, order_id, product_id, sku_id, legacy_sku_key, item_name,
       quantity, unit_price, order_date, order_month, order_status, is_completed,
       item_amount_before_discount, total_discount AS original_item_discount,
       allocated_discount, item_amount_after_discount, has_amount_mismatch
FROM mart.fact_order_items;
