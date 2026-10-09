# Сервер: PocketBase

Файл `pocketbase.exe` в репозиторий не входит: скачайте его со страницы релизов
https://github.com/pocketbase/pocketbase/releases (Windows, amd64) и положите в эту папку.

```bash
./pocketbase.exe serve
```

Панель: http://127.0.0.1:8090/_/ (при первом запуске создайте суперпользователя — это администратор самой базы,
он не связан с учётками приложения). API: http://127.0.0.1:8090/api/. Миграции и тестовые данные применяются при старте.

## Схема (`pb_migrations/`)

Девять коллекций: brands, series, categories, sneakers, customers, loyalty_cards, orders, reviews, promotions.

- 1:1 — customers ↔ loyalty_cards (уникальный индекс по связи);
- 1:N — brands → sneakers, customers → orders, sneakers → orders и reviews, brands → series;
- N:M — sneakers ↔ categories, sneakers ↔ series, sneakers ↔ promotions.

Мягкое удаление — поле `deleted` (дата). Роль — поле `role` у users (client, manager, admin), связь users → customer.

| Файл | Содержимое |
| --- | --- |
| 1700000001 – 1700000003 | коллекции и связи |
| 1700000004 | роли и правила доступа |
| 1700000005 | учётные записи admin, manager, client |
| 1700000006 | каталог для показа: бренды, кроссовки, акция, карта лояльности |
| 1700000007 | тестовые заказы и отзывы для разделов «Заказы», «Отзывы» и «Отчёт» |

Учётные записи (вход по почте): admin@shop.test / admin123, manager@shop.test / manager123, client@shop.test / client123.

## Серверная логика (`pb_hooks/`)

| Файл | Что делает |
| --- | --- |
| `guards.pb.js` | `POST /api/restore/{collection}/{id}` — восстановление (admin); `POST /api/bulk-delete/{collection}` — массовое мягкое удаление (manager) |
| `validation.pb.js` | 422 с ошибкой в поле: остаток больше общего, период акции пересекается с другой акцией; 409 при удалении бренда, на который ссылаются кроссовки |
| `pricing.pb.js` | `POST /api/orders/quote` — расчёт стоимости; при создании заказа цена пересчитывается, остаток уменьшается, нехватка → 409 |
| `reports.pb.js` | `GET /api/stats/summary` — сводка; `GET /api/export/{collection}?fields=...` — CSV |
| `registration.pb.js` | при публичной регистрации роль всегда «client» и создаётся карточка покупателя |

Функции верхнего уровня в хуках не видны обработчикам (JSVM выполняет их изолированно), поэтому вспомогательный код внутри каждого обработчика.

## Заметки

- Запросы с русским текстом из терминала Windows нужно передавать файлом в UTF-8 (`--data-binary @файл.json`).
- Отказ правила доступа PocketBase возвращает 400 без полей, а не 403.
