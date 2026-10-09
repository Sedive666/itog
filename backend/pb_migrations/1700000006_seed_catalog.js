// Тестовый каталог: бренды, серии, категории, кроссовки, акция и карта лояльности клиента.
// Нужен, чтобы сразу было что показать: списки, связи, расчёт стоимости и отчёт.

migrate((app) => {
  const make = (collection, data) => {
    const r = new Record(app.findCollectionByNameOrId(collection))
    for (const k of Object.keys(data)) r.set(k, data[k])
    app.save(r)
    return r
  }

  const nike = make("brands", { name: "Nike", country: "США", year: 1971 })
  const adidas = make("brands", { name: "Adidas", country: "Германия", year: 1949 })
  const nb = make("brands", { name: "New Balance", country: "США", year: 1906 })

  const running = make("categories", { name: "Бег", description: "Кроссовки для бега и тренировок" })
  const lifestyle = make("categories", { name: "Лайфстайл", description: "Повседневные модели" })

  const airMax = make("series", { name: "Air Max", brand: nike.id, year: 1987 })
  const ultra = make("series", { name: "Ultraboost", brand: adidas.id, year: 2015 })
  const n990 = make("series", { name: "990", brand: nb.id, year: 1982 })

  make("sneakers", {
    name: "Air Max 90", sku: "NK-AM90", year: 1990, price: 12990,
    stockTotal: 10, stockAvailable: 10,
    brand: nike.id, series: [airMax.id], categories: [lifestyle.id],
  })
  make("sneakers", {
    name: "Air Zoom Pegasus 40", sku: "NK-PEG40", year: 2023, price: 11490,
    stockTotal: 8, stockAvailable: 8,
    brand: nike.id, categories: [running.id],
  })
  const ub = make("sneakers", {
    name: "Ultraboost 22", sku: "AD-UB22", year: 2022, price: 15990,
    stockTotal: 6, stockAvailable: 2,
    brand: adidas.id, series: [ultra.id], categories: [running.id],
  })
  make("sneakers", {
    name: "990v6", sku: "NB-990V6", year: 2023, price: 17990,
    stockTotal: 5, stockAvailable: 5,
    brand: nb.id, series: [n990.id], categories: [lifestyle.id],
  })

  make("promotions", {
    title: "Осенняя скидка на Ultraboost", percent: 20,
    dateFrom: "2026-09-01", dateTo: "2027-03-31",
    sneakers: [ub.id],
  })

  const ivan = app.findFirstRecordByData("customers", "email", "ivan@shop.test")
  make("loyalty_cards", {
    customer: ivan.id, number: "12345678", level: "Золотая", bonusPoints: 1200, issuedAt: "2026-01-15",
  })
}, (app) => {
  const names = ["Air Max 90", "Air Zoom Pegasus 40", "Ultraboost 22", "990v6"]
  for (const n of names) app.delete(app.findFirstRecordByData("sneakers", "name", n))
  app.delete(app.findFirstRecordByData("promotions", "title", "Осенняя скидка на Ultraboost"))
  app.delete(app.findFirstRecordByData("loyalty_cards", "number", "12345678"))
  for (const n of ["Air Max", "Ultraboost", "990"]) app.delete(app.findFirstRecordByData("series", "name", n))
  for (const n of ["Бег", "Лайфстайл"]) app.delete(app.findFirstRecordByData("categories", "name", n))
  for (const n of ["Nike", "Adidas", "New Balance"]) app.delete(app.findFirstRecordByData("brands", "name", n))
})
