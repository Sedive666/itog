// Роли и правила доступа.
// Роль хранится в users.role; клиент связан с карточкой customer.
// Правила разделяют роли: у каждой роли есть разделы, которых нет у остальных.
// Мягко удалённые записи видны только администратору (deleted != null).
// Восстановление и bulk-delete — в pb_hooks (маршруты с проверкой роли).

migrate((app) => {
  const customers = app.findCollectionByNameOrId("customers")

  const users = app.findCollectionByNameOrId("users")
  users.fields.add(new SelectField({
    name: "role",
    values: ["client", "manager", "admin"],
    maxSelect: 1,
    required: false,
  }))
  users.fields.add(new RelationField({
    name: "customer",
    collectionId: customers.id,
    maxSelect: 1,
    cascadeDelete: false,
  }))
  app.save(users)

  const isStaff = '@request.auth.role = "manager" || @request.auth.role = "admin"'
  const isManager = '@request.auth.role = "manager"'
  const isAdmin = '@request.auth.role = "admin"'
  const authed = '@request.auth.id != ""'
  const liveOrAdmin = `deleted = "" || ${isAdmin}`

  // Каталог: читают все авторизованные, удалённые видит только администратор.
  // Меняет и мягко удаляет менеджер; жёстко удаляет администратор.
  for (const name of ["brands", "series", "categories", "sneakers", "promotions"]) {
    const c = app.findCollectionByNameOrId(name)
    c.listRule = `${authed} && (${liveOrAdmin})`
    c.viewRule = `${authed} && (${liveOrAdmin})`
    c.createRule = isManager
    c.updateRule = isManager
    c.deleteRule = isAdmin
    app.save(c)
  }

  // Клиенты: менеджер видит всех, клиент — только свою карточку.
  const customersCol = app.findCollectionByNameOrId("customers")
  customersCol.listRule = `${isStaff} || id = @request.auth.customer`
  customersCol.viewRule = `${isStaff} || id = @request.auth.customer`
  customersCol.createRule = isManager
  customersCol.updateRule = isManager
  customersCol.deleteRule = isAdmin
  app.save(customersCol)

  // Карта лояльности: клиент видит свою, менеджер — все.
  const cards = app.findCollectionByNameOrId("loyalty_cards")
  cards.listRule = `${isStaff} || customer = @request.auth.customer`
  cards.viewRule = `${isStaff} || customer = @request.auth.customer`
  cards.createRule = isManager
  cards.updateRule = isManager
  cards.deleteRule = isAdmin
  app.save(cards)

  // Заказы: клиент — свои, менеджер — все; создаёт и меняет статус менеджер.
  const orders = app.findCollectionByNameOrId("orders")
  orders.listRule = `${isStaff} || customer = @request.auth.customer`
  orders.viewRule = `${isStaff} || customer = @request.auth.customer`
  orders.createRule = isManager
  orders.updateRule = isManager
  orders.deleteRule = isAdmin
  app.save(orders)

  // Отзывы: читают все авторизованные; пишет клиент от своего имени.
  const reviews = app.findCollectionByNameOrId("reviews")
  reviews.listRule = `${authed} && (${liveOrAdmin})`
  reviews.viewRule = `${authed} && (${liveOrAdmin})`
  reviews.createRule = `@request.auth.role = "client" && customer = @request.auth.customer`
  reviews.updateRule = isAdmin
  reviews.deleteRule = isAdmin
  app.save(reviews)
}, (app) => {
  for (const name of ["brands", "series", "categories", "sneakers", "promotions", "customers", "loyalty_cards", "orders", "reviews"]) {
    const c = app.findCollectionByNameOrId(name)
    c.listRule = null
    c.viewRule = null
    c.createRule = null
    c.updateRule = null
    c.deleteRule = null
    app.save(c)
  }
  const users = app.findCollectionByNameOrId("users")
  users.fields.removeByName("role")
  users.fields.removeByName("customer")
  app.save(users)
})
