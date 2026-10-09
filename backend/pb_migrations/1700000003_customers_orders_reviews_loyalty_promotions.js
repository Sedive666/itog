// Клиенты, карта лояльности (1:1), заказы, отзывы, акции (N:M с кроссовками).
// Связи 1:N: клиент → заказы, кроссовок → заказы, кроссовок → отзывы.

migrate((app) => {
  const customers = new Collection({
    type: "base",
    name: "customers",
    fields: [
      { type: "text", name: "firstName", required: true, min: 2, max: 50 },
      { type: "text", name: "lastName", required: true, min: 2, max: 50 },
      { type: "email", name: "email", required: true },
      { type: "text", name: "phone", required: true, pattern: "^\\+?[0-9 ()-]{10,20}$" },
      { type: "text", name: "city", max: 60 },
      { type: "date", name: "deleted" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_customers_email ON customers (email)"],
  })
  app.save(customers)

  // 1:1 — карта принадлежит ровно одному клиенту; уникальность связи держит индекс.
  const loyaltyCards = new Collection({
    type: "base",
    name: "loyalty_cards",
    fields: [
      {
        type: "relation",
        name: "customer",
        collectionId: customers.id,
        required: true,
        maxSelect: 1,
        cascadeDelete: true,
      },
      { type: "text", name: "number", required: true, pattern: "^[0-9]{8,16}$" },
      { type: "select", name: "level", required: true, values: ["Серебряная", "Золотая", "Платиновая"], maxSelect: 1 },
      { type: "number", name: "bonusPoints", min: 0, max: 1000000 },
      { type: "date", name: "issuedAt" },
      { type: "date", name: "deleted" },
    ],
    indexes: [
      "CREATE UNIQUE INDEX idx_loyalty_customer ON loyalty_cards (customer)",
      "CREATE UNIQUE INDEX idx_loyalty_number ON loyalty_cards (number)",
    ],
  })
  app.save(loyaltyCards)

  const sneakers = app.findCollectionByNameOrId("sneakers")

  const orders = new Collection({
    type: "base",
    name: "orders",
    fields: [
      { type: "text", name: "number", required: true, min: 4, max: 20 },
      {
        type: "relation",
        name: "customer",
        collectionId: customers.id,
        required: true,
        maxSelect: 1,
        cascadeDelete: false,
      },
      {
        type: "relation",
        name: "sneaker",
        collectionId: sneakers.id,
        required: true,
        maxSelect: 1,
        cascadeDelete: false,
      },
      { type: "number", name: "size", required: true, min: 35, max: 48 },
      { type: "number", name: "quantity", required: true, min: 1, max: 20 },
      { type: "number", name: "price", required: true, min: 1, max: 1000000 },
      { type: "select", name: "status", required: true, values: ["Новый", "Оплачен", "Отправлен", "Доставлен", "Отменён"], maxSelect: 1 },
      { type: "date", name: "createdAt" },
      { type: "date", name: "deleted" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_orders_number ON orders (number)"],
  })
  app.save(orders)

  const reviews = new Collection({
    type: "base",
    name: "reviews",
    fields: [
      {
        type: "relation",
        name: "sneaker",
        collectionId: sneakers.id,
        required: true,
        maxSelect: 1,
        cascadeDelete: false,
      },
      {
        type: "relation",
        name: "customer",
        collectionId: customers.id,
        required: true,
        maxSelect: 1,
        cascadeDelete: false,
      },
      { type: "number", name: "rating", required: true, min: 1, max: 5, onlyInt: true },
      { type: "text", name: "text", max: 1000 },
      { type: "date", name: "createdAt" },
      { type: "date", name: "deleted" },
    ],
  })
  app.save(reviews)

  // N:M — акция действует на несколько кроссовков, кроссовок входит в несколько акций.
  const promotions = new Collection({
    type: "base",
    name: "promotions",
    fields: [
      { type: "text", name: "title", required: true, min: 3, max: 100 },
      { type: "number", name: "percent", required: true, min: 1, max: 90, onlyInt: true },
      { type: "date", name: "dateFrom", required: true },
      { type: "date", name: "dateTo", required: true },
      {
        type: "relation",
        name: "sneakers",
        collectionId: sneakers.id,
        maxSelect: 99,
        cascadeDelete: false,
      },
      { type: "date", name: "deleted" },
    ],
  })
  app.save(promotions)
}, (app) => {
  app.delete(app.findCollectionByNameOrId("promotions"))
  app.delete(app.findCollectionByNameOrId("reviews"))
  app.delete(app.findCollectionByNameOrId("orders"))
  app.delete(app.findCollectionByNameOrId("loyalty_cards"))
  app.delete(app.findCollectionByNameOrId("customers"))
})
