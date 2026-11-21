-- Olenenka DWH
-- Расширенный справочник товаров
-- Включаем текущий каталог и удалённые товары из истории заказов.


DROP TABLE IF EXISTS mart.dim_products;

CREATE TABLE mart.dim_products AS
WITH historical_names AS (
    SELECT
        i.product_id,
        TRIM(
            REPLACE(
                REPLACE(
                    REGEXP_REPLACE(
                        i.item_name,
                        '^\[[^]]+\]\s*',
                        ''
                    ),
                    '&quot;', '"'
                ),
                '&amp;', '&'
            )
        ) AS cleaned_name,
        o.created_at
    FROM staging.shop_order_items AS i
    JOIN staging.shop_order AS o
        ON i.order_id = o.order_id
    LEFT JOIN staging.shop_product AS p
        ON i.product_id = p.product_id
    WHERE i.product_id > 0
      AND p.product_id IS NULL
),

name_stats AS (
    SELECT
        product_id,
        cleaned_name,
        COUNT(*) AS uses_count,
        MAX(created_at) AS last_used_at
    FROM historical_names
    WHERE cleaned_name <> ''
    GROUP BY product_id, cleaned_name
),

ranked_names AS (
    SELECT
        *,
        COUNT(*) OVER (
            PARTITION BY product_id
        ) AS distinct_names_count,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY
                uses_count DESC,
                last_used_at DESC,
                cleaned_name
        ) AS name_rank
    FROM name_stats
),

restored_products AS (
    SELECT
        product_id,
        cleaned_name AS product_name,
        distinct_names_count
    FROM ranked_names
    WHERE name_rank = 1
)

-- Товары из сохранившегося каталога
SELECT
    p.product_id,
    p.product_name,
    p.main_category_id,
    p.main_sku_id,
    p.product_status,
    p.catalog_price,
    p.is_published,
    TRUE AS is_in_current_catalog,
    'catalog'::TEXT AS name_source,
    NULL::BIGINT AS distinct_names_count,
    FALSE AS has_multiple_names
FROM staging.shop_product AS p

UNION ALL

-- Исторические товары, отсутствующие в каталоге
SELECT
    h.product_id,
    h.product_name,
    NULL::BIGINT AS main_category_id,
    NULL::BIGINT AS main_sku_id,
    NULL::TEXT AS product_status,
    NULL::NUMERIC(20, 4) AS catalog_price,
    NULL::BOOLEAN AS is_published,
    FALSE AS is_in_current_catalog,
    'order_history'::TEXT AS name_source,
    h.distinct_names_count,
    h.distinct_names_count > 1 AS has_multiple_names
FROM restored_products AS h;


ALTER TABLE mart.dim_products
ADD CONSTRAINT pk_mart_dim_products PRIMARY KEY (product_id);
