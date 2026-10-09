// Справочники: бренды, категории, серии (серия принадлежит бренду).
// Мягкое удаление — поле deleted (дата), как в ПР6 (поле deletedAt).

migrate((app) => {
  const brands = new Collection({
    type: "base",
    name: "brands",
    fields: [
      { type: "text", name: "name", required: true, min: 2, max: 60 },
      { type: "text", name: "country", required: true, max: 60 },
      { type: "number", name: "year", required: true, min: 1900, max: 2100 },
      { type: "date", name: "deleted" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_brands_name ON brands (name)"],
  })
  app.save(brands)

  const categories = new Collection({
    type: "base",
    name: "categories",
    fields: [
      { type: "text", name: "name", required: true, min: 2, max: 60 },
      { type: "text", name: "description", max: 500 },
      { type: "date", name: "deleted" },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_categories_name ON categories (name)"],
  })
  app.save(categories)

  const series = new Collection({
    type: "base",
    name: "series",
    fields: [
      { type: "text", name: "name", required: true, min: 2, max: 60 },
      {
        type: "relation",
        name: "brand",
        collectionId: app.findCollectionByNameOrId("brands").id,
        required: true,
        maxSelect: 1,
        cascadeDelete: false,
      },
      { type: "number", name: "year", min: 1900, max: 2100 },
      { type: "date", name: "deleted" },
    ],
  })
  app.save(series)
}, (app) => {
  app.delete(app.findCollectionByNameOrId("series"))
  app.delete(app.findCollectionByNameOrId("categories"))
  app.delete(app.findCollectionByNameOrId("brands"))
})
