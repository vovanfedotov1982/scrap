class CreateProductCatalogs < ActiveRecord::Migration[6.1]
  def change
    create_table :product_catalogs do |t|
      t.references :product, null: false, foreign_key: true
      t.references :catalog, null: false, foreign_key: true

      t.timestamps
    end
  end
end
