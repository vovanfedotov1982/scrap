class Catalog < ApplicationRecord
    has_many :product_catalogs, dependent: :destroy
    has_many :products, through: :product_catalogs
end
