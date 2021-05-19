class Product < ApplicationRecord
    has_many :product_catalogs, dependent: :destroy
    validates :url, uniqueness: true
end
