-- Olenenka DWH
-- Справочник исторических артикулов из старых заказов
-- Используем позиции, у которых product_id и sku_id равны 0.
-- Если один артикул встречается с разными названиями,
-- временно разделяем его по нормализованному названию.


DROP TABLE IF EXISTS mart.dim_legacy_skus;

CREATE TABLE mart.dim_legacy_skus AS
WITH name_variants AS (
    SELECT
        legacy_sku_key,
        historical_sku,
        name_group,
        product_name,
        MAX(names_count) AS names_count,
        COUNT(*) AS uses_count
    FROM staging.legacy_sku_mapping
    GROUP BY legacy_sku_key, historical_sku, name_group, product_name
),

ranked_names AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY historical_sku, name_group
            ORDER BY uses_count DESC, product_name
        ) AS name_rank
    FROM name_variants
)

SELECT
    legacy_sku_key,

    historical_sku,
    product_name,
    name_group AS normalized_name_group,

    names_count > 1 AS has_ambiguous_code,
    names_count AS names_per_code

FROM ranked_names
WHERE name_rank = 1;


-- Один ключ соответствует одной исторической группе.
ALTER TABLE mart.dim_legacy_skus
ADD CONSTRAINT pk_mart_dim_legacy_skus
PRIMARY KEY (legacy_sku_key);
