// Тестовые заказы и отзывы, чтобы разделы «Заказы», «Отзывы» и «Отчёт» не были пустыми.
// Цены посчитаны по тем же правилам, что и на сервере: цена × (1 − акция) × (1 − карта «Золотая» 5 %).

migrate((app) => {
  const make = (collection, data) => {
    const r = new Record(app.findCollectionByNameOrId(collection))
    for (const k of Object.keys(data)) r.set(k, data[k])
    app.save(r)
    return r
  }
  const sneaker = (sku) => app.findFirstRecordByData("sneakers", "sku", sku)

  const ivan = app.findFirstRecordByData("customers", "email", "ivan@shop.test")
  const airMax = sneaker("NK-AM90")
  const pegasus = sneaker("NK-PEG40")
  const ultra = sneaker("AD-UB22")
  const nb = sneaker("NB-990V6")

  // 12990 × 0,95; 11490 × 0,95; 15990 × 0,80 × 0,95; 17990 × 0,95
  make("orders", {
    number: "ORD-1001", customer: ivan.id, sneaker: airMax.id, size: 42, quantity: 1,
    price: 12341, status: "Доставлен", createdAt: "2026-09-20",
  })
  make("orders", {
    number: "ORD-1002", customer: ivan.id, sneaker: ultra.id, size: 43, quantity: 1,
    price: 12152, status: "Оплачен", createdAt: "2026-10-02",
  })
  make("orders", {
    number: "ORD-1003", customer: ivan.id, sneaker: pegasus.id, size: 41, quantity: 2,
    price: 10916, status: "Новый", createdAt: "2026-10-06",
  })
  make("orders", {
    number: "ORD-1004", customer: ivan.id, sneaker: nb.id, size: 42, quantity: 1,
    price: 17091, status: "Отменён", createdAt: "2026-10-07",
  })

  make("reviews", {
    sneaker: airMax.id, customer: ivan.id, rating: 5,
    text: "Удобные, по размеру, выглядят отлично.", createdAt: "2026-09-28",
  })
  make("reviews", {
    sneaker: ultra.id, customer: ivan.id, rating: 4,
    text: "Хорошая амортизация, но дороговато без скидки.", createdAt: "2026-10-04",
  })
  make("reviews", {
    sneaker: pegasus.id, customer: ivan.id, rating: 3,
    text: "Нормальные беговые, подошва быстро стёрлась.", createdAt: "2026-10-05",
  })
}, (app) => {
  for (const n of ["ORD-1001", "ORD-1002", "ORD-1003", "ORD-1004"]) {
    app.delete(app.findFirstRecordByData("orders", "number", n))
  }
  for (const r of app.findRecordsByFilter("reviews", "customer.email = 'ivan@shop.test'", "", 0, 0)) {
    app.delete(r)
  }
})
