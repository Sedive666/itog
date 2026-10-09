// Серверные маршруты, которых нет в PocketBase из коробки:
//   POST /api/restore/{collection}/{id}   — восстановить мягко удалённую запись (admin)
//   POST /api/bulk-delete/{collection}    — мягко удалить несколько записей (manager)
//     тело: {"ids": ["id1", "id2"]}; ответ: {"deleted": n}
// Маршруты работают с правами приложения, поэтому роль проверяется здесь вручную.
// Вспомогательные функции объявлены внутри обработчиков: JSVM не видит функций верхнего уровня.

routerAdd("POST", "/api/restore/{collection}/{id}", (e) => {
  const role = e.auth ? e.auth.getString("role") : ""
  if (role !== "admin") {
    throw new ForbiddenError("Восстанавливать записи может только администратор")
  }
  const record = $app.findRecordById(e.request.pathValue("collection"), e.request.pathValue("id"))
  record.set("deleted", "")
  $app.save(record)
  return e.json(200, record)
}, $apis.requireAuth())

routerAdd("POST", "/api/bulk-delete/{collection}", (e) => {
  const role = e.auth ? e.auth.getString("role") : ""
  if (role !== "manager") {
    throw new ForbiddenError("Удалять записи пачкой может только менеджер")
  }
  const body = e.requestInfo().body
  const ids = body.ids || []
  if (!Array.isArray(ids) || ids.length === 0) {
    throw new BadRequestError("Не переданы идентификаторы", {
      ids: new ValidationError("required", "Выберите хотя бы одну запись"),
    })
  }
  const collection = e.request.pathValue("collection")
  const now = new Date().toISOString()
  let deleted = 0
  for (const id of ids) {
    const record = $app.findRecordById(collection, id)
    if (record.getString("deleted") !== "") continue
    record.set("deleted", now)
    $app.save(record)
    deleted++
  }
  return e.json(200, { deleted: deleted })
}, $apis.requireAuth())
