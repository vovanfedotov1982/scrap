class CreateCatalogs < ActiveRecord::Migration[6.1]
  def change
    create_table :catalogs do |t|
      t.string :name
      t.string :url
      t.integer :level
      t.string :parent_url

      t.timestamps
    end
  end
end
