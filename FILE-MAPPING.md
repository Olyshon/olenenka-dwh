# Файлы первого коммита

Все SQL сохранены по исходным относительным путям. Этот список соответствует содержимому комплекта.

| Файл | Назначение |
|---|---|
| .gitattributes | Сохраняет байты SQL при добавлении в Git |
| .gitignore | Разрешённый состав файлов и исключения |
| FILE-MAPPING.md | Полный список первого коммита |
| README.md | Презентация проекта и результаты |
| SHA256SUMS | SHA256 всех 37 SQL |
| docs/AUDIT.md | Приёмка, изменения и аудит публикации |
| docs/METHODOLOGY.md | Методика, ограничения и трактовка BI |
| docs/RUNBOOK.md | Локальная пересборка и проверка |
| sql/00_rebuild.sql | Полная транзакционная пересборка и запуск DQ |
| sql/01_raw/00_create_database.sql | Разовое создание тестовой базы |
| sql/01_raw/01_create_schemas.sql | Создание RAW, STAGING и MART |
| sql/01_raw/02_create_raw_tables.sql | DDL шести исходных таблиц |
| sql/01_raw/03_load_raw_csv.sql | Разовая загрузка приватного RAW через COPY |
| sql/02_data_quality/01_raw_contract.sql | Типы, обязательность, ключи и связи RAW |
| sql/02_data_quality/02_staging_reconciliation.sql | Сверка переноса из RAW |
| sql/02_data_quality/03_mart_integrity.sql | Целостность фактов, справочников и legacy-ключей |
| sql/02_data_quality/04_financial_reconciliation.sql | Независимая финансовая сверка и скидки |
| sql/02_data_quality/05_bi_reconciliation.sql | Сверки продаж, ABC, XYZ и матрицы |
| sql/02_data_quality/06_historical_snapshot.sql | Контрольные числа и исключения исторического снимка |
| sql/03_staging/stg_legacy_sku_mapping.sql | Сопоставление позиций с историческими ключами |
| sql/03_staging/stg_shop_category.sql | Типизация категорий и иерархии |
| sql/03_staging/stg_shop_category_products.sql | Типизация связей товаров с категориями |
| sql/03_staging/stg_shop_order.sql | Типизация заказов, даты и классификация аккаунтов |
| sql/03_staging/stg_shop_order_items.sql | Типизация позиций и исходная стоимость |
| sql/03_staging/stg_shop_product.sql | Типизация карточек каталога |
| sql/03_staging/stg_shop_product_skus.sql | Типизация модификаций и артикулов |
| sql/04_marts/00_prepare_rebuild.sql | Снятие зависимых финансовых представлений |
| sql/04_marts/abc_skus.sql | Классификация по доле оборота |
| sql/04_marts/abc_xyz_skus.sql | Матрица ABC-XYZ |
| sql/04_marts/dim_legacy_skus.sql | Справочник исторических групп |
| sql/04_marts/dim_products.sql | Товары текущего каталога и истории |
| sql/04_marts/dim_skus.sql | Модификации текущего каталога и истории |
| sql/04_marts/fact_order_items.sql | Факт позиций с распределением скидки |
| sql/04_marts/fact_order_items_financial.sql | Совместимое финансовое представление |
| sql/04_marts/fact_orders.sql | Факт заказов |
| sql/04_marts/order_financial_reconciliation.sql | Сверка товара, доставки и итога заказа |
| sql/04_marts/product_exclusions.sql | Подтверждённые технические группы |
| sql/04_marts/sales_by_sku.sql | Оборот и количество по товарной группе |
| sql/04_marts/sales_monthly.sql | Динамика заказов и каналов по месяцам |
| sql/04_marts/sku_sales_monthly.sql | Продажи по товарному ключу и месяцу |
| sql/04_marts/xyz_skus.sql | Относительная классификация по CV |
| sql/05_exploration/01_order_scope.sql | Исследование статусов, охвата и аккаунтов |
| sql/05_exploration/02_historical_identity.sql | Исследование исторической идентификации |
| sql/05_exploration/03_discount_allocation.sql | Исследование скидок и расхождений |
| sql/05_exploration/04_assortment.sql | Исследование технических групп и ассортимента |
