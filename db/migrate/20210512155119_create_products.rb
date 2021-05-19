class CreateProducts < ActiveRecord::Migration[6.1]
  def change
    create_table :products do |t|
      t.string :name
      t.string :sku
      t.integer :price
      t.string :url

      t.timestamps
    end
  end
end
