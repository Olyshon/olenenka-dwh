-- Olenenka DWH
-- Расширенный справочник SKU
-- Сохраняем текущие модификации и восстанавливаем удалённые по заказам.


DROP TABLE IF EXISTS mart.dim_skus;

CREATE TABLE mart.dim_skus AS
WITH historical_items AS (
    SELECT
        i.sku_id,
        i.product_id,
        NULLIF(TRIM(i.sku_code), '') AS sku_code,
        NULLIF(TRIM(i.item_name), '') AS item_name,
        o.created_at
    FROM staging.shop_order_items AS i
    JOIN staging.shop_order AS o
        ON i.order_id = o.order_id
    LEFT JOIN staging.shop_product_skus AS s
        ON i.sku_id = s.sku_id
    WHERE i.sku_id > 0
      AND s.sku_id IS NULL
),

sku_codes AS (
    SELECT
        sku_id,
        sku_code,
        COUNT(*) AS uses_count,
        MAX(created_at) AS last_used_at
    FROM historical_items
    WHERE sku_code IS NOT NULL
    GROUP BY sku_id, sku_code
),

ranked_codes AS (
    SELECT
        *,
        COUNT(*) OVER (
            PARTITION BY sku_id
        ) AS sku_codes_count,
        ROW_NUMBER() OVER (
            PARTITION BY sku_id
            ORDER BY uses_count DESC, last_used_at DESC, sku_code
        ) AS code_rank
    FROM sku_codes
),

sku_names AS (
    SELECT
        sku_id,
        item_name,
        COUNT(*) AS uses_count,
        MAX(created_at) AS last_used_at
    FROM historical_items
    WHERE item_name IS NOT NULL
    GROUP BY sku_id, item_name
),

ranked_names AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY sku_id
            ORDER BY uses_count DESC, last_used_at DESC, item_name
        ) AS name_rank
    FROM sku_names
),

restored_skus AS (
    SELECT DISTINCT
        sku_id,
        product_id
    FROM historical_items
)

-- SKU из сохранившегося каталога
SELECT
    s.sku_id,
    s.product_id,
    s.sku_code,
    s.sku_name,
    s.catalog_price,
    s.catalog_purchase_price,
    s.stock_count,
    TRUE AS is_in_current_catalog,
    'catalog'::TEXT AS data_source,
    NULL::BIGINT AS sku_codes_count,
    FALSE AS has_multiple_sku_codes
FROM staging.shop_product_skus AS s

UNION ALL

-- Исторические SKU, отсутствующие в каталоге
SELECT
    h.sku_id,
    h.product_id,
    c.sku_code,
    n.item_name AS sku_name,
    NULL::NUMERIC(20, 4) AS catalog_price,
    NULL::NUMERIC(20, 4) AS catalog_purchase_price,
    NULL::NUMERIC(20, 4) AS stock_count,
    FALSE AS is_in_current_catalog,
    'order_history'::TEXT AS data_source,
    COALESCE(c.sku_codes_count, 0) AS sku_codes_count,
    COALESCE(c.sku_codes_count > 1, FALSE) AS has_multiple_sku_codes
FROM restored_skus AS h
LEFT JOIN ranked_codes AS c
    ON h.sku_id = c.sku_id
   AND c.code_rank = 1
LEFT JOIN ranked_names AS n
    ON h.sku_id = n.sku_id
   AND n.name_rank = 1;


ALTER TABLE mart.dim_skus
ADD CONSTRAINT pk_mart_dim_skus PRIMARY KEY (sku_id);
