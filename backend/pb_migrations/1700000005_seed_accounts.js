// Три учётные записи из ПР6: admin / manager / client.
// Вход по email (identity = manager@shop.test, пароль manager123 и т.д.).
// Логин по username в этой сборке не включён. Пароли тестовые.

migrate((app) => {
  const users = app.findCollectionByNameOrId("users")
  const customers = app.findCollectionByNameOrId("customers")

  // Клиент привязан к карточке покупателя, как в ПР6.
  const customer = new Record(customers)
  customer.set("firstName", "Иван")
  customer.set("lastName", "Петров")
  customer.set("email", "ivan@shop.test")
  customer.set("phone", "+79001234567")
  customer.set("city", "Москва")
  app.save(customer)

  const accounts = [
    { username: "admin", password: "admin123", role: "admin" },
    { username: "manager", password: "manager123", role: "manager" },
    { username: "client", password: "client123", role: "client", customer: customer.id },
  ]

  for (const a of accounts) {
    const u = new Record(users)
    u.set("username", a.username)
    u.set("email", `${a.username}@shop.test`)
    u.setPassword(a.password)
    u.set("role", a.role)
    if (a.customer) u.set("customer", a.customer)
    u.setVerified(true)
    app.save(u)
  }
}, (app) => {
  for (const name of ["admin", "manager", "client"]) {
    const u = app.findFirstRecordByData("users", "username", name)
    app.delete(u)
  }
  const c = app.findFirstRecordByData("customers", "email", "ivan@shop.test")
  app.delete(c)
})
