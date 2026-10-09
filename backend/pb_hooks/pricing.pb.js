// Расчёт стоимости по правилам.
//   1. Базовая цена — sneakers.price.
//   2. Акция: если на кроссовок действует активная акция (dateFrom ≤ сейчас ≤ dateTo, не удалена),
//      берётся наибольший процент.
//   3. Скидка по карте лояльности: Серебряная 3 %, Золотая 5 %, Платиновая 10 %.
//   Скидки применяются последовательно: цена × (1 − акция) × (1 − карта), округление до рубля.
//
// POST /api/orders/quote  {sneakerId, customerId?, quantity}  → расчёт без записи в базу.
// Хук на создание заказа пересчитывает цену на сервере, уменьшает остаток и отказывает при нехватке (409).
// Вспомогательные функции объявлены внутри обработчиков: JSVM не видит функций верхнего уровня.

routerAdd("POST", "/api/orders/quote", (e) => {
  const body = e.requestInfo().body
  const sneakerId = body.sneakerId || ""
  const customerId = body.customerId || ""
  const quantity = parseInt(body.quantity || 1, 10)
  if (!sneakerId || !(quantity >= 1)) {
    throw new BadRequestError("Укажите кроссовок и количество", {
      quantity: new ValidationError("invalid", "Количество должно быть не меньше 1"),
    })
  }

  const LOYALTY = { "Серебряная": 3, "Золотая": 5, "Платиновая": 10 }
  const sneaker = $app.findRecordById("sneakers", sneakerId)
  const basePrice = sneaker.getInt("price")

  const now = Date.now()
  const promos = $app.findRecordsByFilter("promotions", "deleted = ''", "", 0, 0)
  let promoPercent = 0
  for (const p of promos) {
    if (!p.getStringSlice("sneakers").includes(sneakerId)) continue
    const from = new Date(p.getString("dateFrom")).getTime()
    const to = new Date(p.getString("dateTo")).getTime()
    if (from <= now && now <= to && p.getInt("percent") > promoPercent) {
      promoPercent = p.getInt("percent")
    }
  }

  let loyaltyPercent = 0
  if (customerId) {
    const cards = $app.findRecordsByFilter("loyalty_cards", `customer = "${customerId}" && deleted = ''`, "", 1, 0)
    if (cards.length > 0) loyaltyPercent = LOYALTY[cards[0].getString("level")] || 0
  }

  const unitPrice = Math.round(basePrice * (1 - promoPercent / 100) * (1 - loyaltyPercent / 100))
  return e.json(200, {
    basePrice: basePrice,
    promoPercent: promoPercent,
    loyaltyPercent: loyaltyPercent,
    unitPrice: unitPrice,
    quantity: quantity,
    total: unitPrice * quantity,
  })
}, $apis.requireAuth())

onRecordCreateRequest((e) => {
  const LOYALTY = { "Серебряная": 3, "Золотая": 5, "Платиновая": 10 }
  const quantity = e.record.getInt("quantity")
  const sneaker = $app.findRecordById("sneakers", e.record.getString("sneaker"))

  if (sneaker.getInt("stockAvailable") < quantity) {
    throw new ApiError(409, `Недостаточно пар на складе: доступно ${sneaker.getInt("stockAvailable")}`)
  }

  const now = Date.now()
  const promos = $app.findRecordsByFilter("promotions", "deleted = ''", "", 0, 0)
  let promoPercent = 0
  for (const p of promos) {
    if (!p.getStringSlice("sneakers").includes(sneaker.id)) continue
    const from = new Date(p.getString("dateFrom")).getTime()
    const to = new Date(p.getString("dateTo")).getTime()
    if (from <= now && now <= to && p.getInt("percent") > promoPercent) {
      promoPercent = p.getInt("percent")
    }
  }

  let loyaltyPercent = 0
  const cards = $app.findRecordsByFilter("loyalty_cards", `customer = "${e.record.getString("customer")}" && deleted = ''`, "", 1, 0)
  if (cards.length > 0) loyaltyPercent = LOYALTY[cards[0].getString("level")] || 0

  e.record.set("price", Math.round(sneaker.getInt("price") * (1 - promoPercent / 100) * (1 - loyaltyPercent / 100)))
  e.record.set("sneaker", sneaker.id)

  sneaker.set("stockAvailable", sneaker.getInt("stockAvailable") - quantity)
  $app.save(sneaker)

  e.next()
}, "orders")
