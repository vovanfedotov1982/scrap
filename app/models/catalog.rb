class Catalog < ApplicationRecord
    has_many :product_catalogs, dependent: :destroy
end
