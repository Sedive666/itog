// Регистрация покупателя. Публичная форма не может выбрать роль:
// сервер всегда ставит «client» и создаёт карточку покупателя из введённых данных.
// Создание пользователя администратором или менеджером не меняется.
// Вспомогательные функции объявлены внутри обработчика: JSVM не видит функций верхнего уровня.

onRecordCreateRequest((e) => {
  const role = e.auth ? e.auth.getString("role") : ""
  const isStaff = role === "admin" || role === "manager"

  if (!isStaff) {
    // Поля покупателя приходят в теле запроса: в коллекции users их нет.
    const body = e.requestInfo().body
    e.record.set("role", "client")

    const customers = $app.findCollectionByNameOrId("customers")
    const customer = new Record(customers)
    customer.set("firstName", body.firstName || "")
    customer.set("lastName", body.lastName || "")
    customer.set("email", e.record.getString("email"))
    customer.set("phone", body.phone || "")
    $app.save(customer)
    e.record.set("customer", customer.id)
  }

  e.next()
}, "users")
