-- Olenenka DWH
-- Связи товаров с категориями
-- Один товар может относиться к нескольким категориям.



DROP TABLE IF EXISTS staging.shop_category_products;


CREATE TABLE staging.shop_category_products AS
SELECT product_id::BIGINT AS product_id,
       category_id::BIGINT AS category_id,
sort AS sort_order_raw
FROM raw.shop_category_products;

-- Одна пара товар-категория должна встречаться один раз.

ALTER TABLE staging.shop_category_products ADD CONSTRAINT pk_staging_shop_category_products PRIMARY KEY (product_id,
                                                                                                         category_id);
