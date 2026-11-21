-- Original legacy identity rules.
DROP TABLE IF EXISTS staging.legacy_sku_mapping;
CREATE TABLE staging.legacy_sku_mapping AS
WITH historical_items AS (
    SELECT
        item_id,
        SUBSTRING(item_name FROM '^\[([^]]+)\]') AS historical_sku,
        TRIM(
            REGEXP_REPLACE(item_name, '^\[[^]]+\]\s*', '')
        ) AS product_name,
        LOWER(
            TRIM(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(item_name, '^\[[^]]+\]\s*', ''),
                    '\s+', ' ', 'g'
                )
            )
        ) AS normalized_name
    FROM staging.shop_order_items
    WHERE product_id = 0
      AND sku_id = 0
),

sku_stats AS (
    SELECT
        historical_sku,
        COUNT(DISTINCT normalized_name) AS names_count
    FROM historical_items
    WHERE historical_sku IS NOT NULL
    GROUP BY historical_sku
),

identified_items AS (
    SELECT
        h.item_id,
        h.historical_sku,
        h.product_name,
        h.normalized_name,
        s.names_count,
        CASE
            WHEN s.names_count > 1 THEN h.normalized_name
            ELSE ''
        END AS name_group
    FROM historical_items AS h
    JOIN sku_stats AS s
        ON h.historical_sku = s.historical_sku
)
SELECT item_id, historical_sku, product_name, names_count, name_group,
       'legacy:' || MD5(historical_sku || '|' || name_group) AS legacy_sku_key
FROM identified_items;
ALTER TABLE staging.legacy_sku_mapping ADD PRIMARY KEY (item_id);
