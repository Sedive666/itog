// Кроссовки: бренд (N:1), серии и категории (N:M), остатки.
// Проверки stockAvailable ≤ stockTotal и уникальность sku — в pb_hooks, здесь только базовые ограничения полей.

migrate((app) => {
  const sneakers = new Collection({
    type: "base",
    name: "sneakers",
    fields: [
      { type: "text", name: "name", required: true, min: 2, max: 100 },
      { type: "text", name: "sku", required: true, min: 4, max: 20, pattern: "^[A-Za-z0-9-]{4,20}$" },
      { type: "number", name: "year", required: true, min: 1990, max: 2100 },
      { type: "number", name: "price", required: true, min: 1, max: 1000000 },
      { type: "number", name: "stockTotal", required: true, min: 0, max: 100000 },
      { type: "number", name: "stockAvailable", required: true, min: 0, max: 100000 },
      {
        type: "relation",
        name: "brand",
        collectionId: app.findCollectionByNameOrId("brands").id,
        required: true,
        maxSelect: 1,
        cascadeDelete: false,
      },
      {
        type: "relation",
        name: "series",
        collectionId: app.findCollectionByNameOrId("series").id,
        maxSelect: 99,
        cascadeDelete: false,
      },
      {
        type: "relation",
        name: "categories",
        collectionId: app.findCollectionByNameOrId("categories").id,
        maxSelect: 99,
        cascadeDelete: false,
      },
      { type: "date", name: "deleted" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_sneakers_sku ON sneakers (sku)"],
  })
  app.save(sneakers)
}, (app) => {
  app.delete(app.findCollectionByNameOrId("sneakers"))
})
