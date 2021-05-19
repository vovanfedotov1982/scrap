class ProductCatalog < ApplicationRecord
  belongs_to :product
  belongs_to :catalog
end
