// Отчёт и экспорт (пункт 20).
//   GET /api/stats/summary — сводка для менеджера и администратора:
//     число заказов, выручка (без отменённых), выручка по брендам, заказы по статусам, мало на складе.
//   GET /api/export/{collection}?fields=name,sku — CSV по выбранным полям, только менеджер и администратор.
// Вспомогательные функции объявлены внутри обработчиков: JSVM не видит функций верхнего уровня.

routerAdd("GET", "/api/stats/summary", (e) => {
  const role = e.auth ? e.auth.getString("role") : ""
  if (role !== "manager" && role !== "admin") {
    throw new ForbiddenError("Сводка доступна менеджеру и администратору")
  }

  const orders = $app.findRecordsByFilter("orders", "deleted = ''", "", 0, 0)
  const sneakers = $app.findRecordsByFilter("sneakers", "deleted = ''", "", 0, 0)
  const brands = $app.findRecordsByFilter("brands", "deleted = ''", "", 0, 0)

  const brandName = {}
  for (const b of brands) brandName[b.id] = b.getString("name")
  const sneakerBrand = {}
  for (const s of sneakers) sneakerBrand[s.id] = brandName[s.getString("brand")] || "—"

  const statuses = {}
  const byBrand = {}
  let revenue = 0
  let active = 0
  for (const o of orders) {
    const status = o.getString("status")
    statuses[status] = (statuses[status] || 0) + 1
    if (status === "Отменён") continue
    active++
    const sum = o.getInt("price") * o.getInt("quantity")
    revenue += sum
    const brand = sneakerBrand[o.getString("sneaker")] || "—"
    byBrand[brand] = (byBrand[brand] || 0) + sum
  }

  const lowStock = sneakers.filter((s) => s.getInt("stockAvailable") <= 2).length

  return e.json(200, {
    ordersTotal: orders.length,
    ordersActive: active,
    revenue: revenue,
    byBrand: Object.keys(byBrand).map((k) => ({ brand: k, revenue: byBrand[k] })),
    byStatus: Object.keys(statuses).map((k) => ({ status: k, count: statuses[k] })),
    lowStock: lowStock,
  })
}, $apis.requireAuth())

routerAdd("GET", "/api/export/{collection}", (e) => {
  const role = e.auth ? e.auth.getString("role") : ""
  if (role !== "manager" && role !== "admin") {
    throw new ForbiddenError("Экспорт доступен менеджеру и администратору")
  }
  const allowed = ["brands", "series", "categories", "sneakers", "customers", "orders", "reviews", "promotions"]
  const collection = e.request.pathValue("collection")
  if (allowed.indexOf(collection) < 0) {
    throw new NotFoundError("Такую таблицу нельзя выгрузить")
  }

  const fields = (e.request.url.query().get("fields") || "").split(",").filter((f) => f.length > 0)
  if (fields.length === 0) {
    throw new BadRequestError("Не выбраны поля", {
      fields: new ValidationError("required", "Выберите хотя бы одно поле"),
    })
  }

  const esc = (v) => {
    const s = v === null || v === undefined ? "" : String(v)
    return /[",\n;]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s
  }
  const records = $app.findRecordsByFilter(collection, "deleted = ''", "", 0, 0)
  const lines = [fields.join(",")]
  for (const r of records) {
    lines.push(fields.map((f) => esc(r.get(f))).join(","))
  }

  e.response.header().set("Content-Type", "text/csv; charset=utf-8")
  e.response.header().set("Content-Disposition", `attachment; filename="${collection}.csv"`)
  return e.string(200, "﻿" + lines.join("\n"))
}, $apis.requireAuth())
