-- Olenenka DWH
-- Создание исходных таблиц Webasyst
-- Все поля загружаются как TEXT без изменения исходных значений.
-- Выполнять в базе olenenka_dwh после создания схем.


-- Заказы: статусы, даты, суммы, скидки и оплата.
-- Одна строка — один заказ.
CREATE TABLE raw.shop_order (
    id TEXT,
    contact_id TEXT,
    create_datetime TEXT,
    update_datetime TEXT,
    state_id TEXT,
    total TEXT,
    currency TEXT,
    rate TEXT,
    tax TEXT,
    shipping TEXT,
    discount TEXT,
    assigned_contact_id TEXT,
    paid_year TEXT,
    paid_quarter TEXT,
    paid_month TEXT,
    paid_date TEXT,
    is_first TEXT,
    comment TEXT
);


-- Товарные позиции заказов.
-- Одна строка — одна позиция заказа, связь через order_id.
CREATE TABLE raw.shop_order_items (
    id TEXT,
    order_id TEXT,
    name TEXT,
    product_id TEXT,
    sku_id TEXT,
    sku_code TEXT,
    type TEXT,
    service_id TEXT,
    service_variant_id TEXT,
    price TEXT,
    quantity TEXT,
    parent_id TEXT,
    stock_id TEXT,
    purchase_price TEXT,
    total_discount TEXT
);


-- Справочник товаров на момент выгрузки.
-- Исторические товары могут отсутствовать в текущем каталоге.
CREATE TABLE raw.shop_product (
    id TEXT,
    id_1c TEXT,
    name TEXT,
    summary TEXT,
    meta_title TEXT,
    meta_keywords TEXT,
    meta_description TEXT,
    description TEXT,
    contact_id TEXT,
    create_datetime TEXT,
    edit_datetime TEXT,
    status TEXT,
    type_id TEXT,
    image_id TEXT,
    image_filename TEXT,
    sku_id TEXT,
    ext TEXT,
    url TEXT,
    rating TEXT,
    price TEXT,
    compare_price TEXT,
    currency TEXT,
    min_price TEXT,
    max_price TEXT,
    tax_id TEXT,
    count TEXT,
    cross_selling TEXT,
    upselling TEXT,
    rating_count TEXT,
    total_sales TEXT,
    category_id TEXT,
    badge TEXT,
    sku_type TEXT,
    base_price_selectable TEXT,
    compare_price_selectable TEXT,
    purchase_price_selectable TEXT,
    sku_count TEXT,
    ean13 TEXT
);


-- SKU: модификации товаров, артикулы, цены и остатки.
-- Связь с товарами через product_id.
-- Данные отражают состояние на момент выгрузки.
CREATE TABLE raw.shop_product_skus (
    id TEXT,
    product_id TEXT,
    id_1c TEXT,
    sku TEXT,
    sort TEXT,
    name TEXT,
    image_id TEXT,
    price TEXT,
    primary_price TEXT,
    purchase_price TEXT,
    compare_price TEXT,
    count TEXT,
    available TEXT,
    dimension_id TEXT,
    file_name TEXT,
    file_size TEXT,
    file_description TEXT,
    virtual TEXT,
    ean13 TEXT
);


-- Категории товаров и их иерархия.
-- parent_id, left_key, right_key и depth описывают вложенность.
CREATE TABLE raw.shop_category (
    id TEXT,
    id_1c TEXT,
    left_key TEXT,
    right_key TEXT,
    depth TEXT,
    parent_id TEXT,
    name TEXT,
    meta_title TEXT,
    meta_keywords TEXT,
    meta_description TEXT,
    type TEXT,
    url TEXT,
    full_url TEXT,
    count TEXT,
    description TEXT,
    conditions TEXT,
    create_datetime TEXT,
    edit_datetime TEXT,
    filter TEXT,
    smartfilters TEXT,
    smartfilters_name TEXT,
    sort_products TEXT,
    include_sub_categories TEXT,
    status TEXT,
    seo_description TEXT
);


-- Связи товаров с категориями.
-- Один товар может входить в несколько категорий.
-- Составной ключ: product_id + category_id.
CREATE TABLE raw.shop_category_products (
    product_id TEXT,
    category_id TEXT,
    sort TEXT
);
