// Проверки, которые нужны по заданию и которых нет в PocketBase:
//   - 422 с ошибками по полям: stockAvailable > stockTotal, пересечение акций;
//   - 409: удаление бренда, на который ссылаются кроссовки.
// Формат 422: {"message": "...", "data": {"поле": {"code", "message"}}}.
// Вспомогательные функции объявлены внутри обработчиков: JSVM не видит функций верхнего уровня.

onRecordCreateRequest((e) => {
  const total = e.record.getInt("stockTotal")
  const available = e.record.getInt("stockAvailable")
  if (available > total) {
    throw new ApiError(422, "Ошибка валидации", {
      stockAvailable: new ValidationError("invalid", "Доступно пар не может быть больше общего количества"),
    })
  }
  e.next()
}, "sneakers")

onRecordUpdateRequest((e) => {
  const total = e.record.getInt("stockTotal")
  const available = e.record.getInt("stockAvailable")
  if (available > total) {
    throw new ApiError(422, "Ошибка валидации", {
      stockAvailable: new ValidationError("invalid", "Доступно пар не может быть больше общего количества"),
    })
  }
  e.next()
}, "sneakers")

// Акции одного кроссовка не должны пересекаться по датам.
// Сравниваем в JS, потому что фильтры с подстановкой параметров не проверены.
onRecordCreateRequest((e) => {
  const from = new Date(e.record.getString("dateFrom")).getTime()
  const to = new Date(e.record.getString("dateTo")).getTime()
  if (!(from <= to)) {
    throw new ApiError(422, "Ошибка валидации", {
      dateTo: new ValidationError("invalid", "Дата окончания раньше даты начала"),
    })
  }
  const sneakerIds = e.record.getStringSlice("sneakers")
  const others = $app.findRecordsByFilter("promotions", "deleted = ''", "", 0, 0)
  for (const p of others) {
    const shares = p.getStringSlice("sneakers").some((id) => sneakerIds.includes(id))
    if (!shares) continue
    const pf = new Date(p.getString("dateFrom")).getTime()
    const pt = new Date(p.getString("dateTo")).getTime()
    if (from <= pt && pf <= to) {
      throw new ApiError(422, "Ошибка валидации", {
        dateFrom: new ValidationError("invalid", `Период пересекается с акцией «${p.getString("title")}»`),
      })
    }
  }
  e.next()
}, "promotions")

onRecordUpdateRequest((e) => {
  const from = new Date(e.record.getString("dateFrom")).getTime()
  const to = new Date(e.record.getString("dateTo")).getTime()
  if (!(from <= to)) {
    throw new ApiError(422, "Ошибка валидации", {
      dateTo: new ValidationError("invalid", "Дата окончания раньше даты начала"),
    })
  }
  const sneakerIds = e.record.getStringSlice("sneakers")
  const others = $app.findRecordsByFilter("promotions", "deleted = ''", "", 0, 0)
  for (const p of others) {
    if (p.id === e.record.id) continue
    const shares = p.getStringSlice("sneakers").some((id) => sneakerIds.includes(id))
    if (!shares) continue
    const pf = new Date(p.getString("dateFrom")).getTime()
    const pt = new Date(p.getString("dateTo")).getTime()
    if (from <= pt && pf <= to) {
      throw new ApiError(422, "Ошибка валидации", {
        dateFrom: new ValidationError("invalid", `Период пересекается с акцией «${p.getString("title")}»`),
      })
    }
  }
  e.next()
}, "promotions")

// Удаление бренда, на который ещё ссылаются кроссовки, — 409.
onRecordDeleteRequest((e) => {
  const refs = $app.findRecordsByFilter("sneakers", `brand = "${e.record.id}"`, "", 0, 0)
  if (refs.length > 0) {
    throw new ApiError(409, `Нельзя удалить бренд: на него ссылаются кроссовки (${refs.length})`)
  }
  e.next()
}, "brands")
