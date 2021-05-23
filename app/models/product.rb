class Product < ApplicationRecord
    has_many :product_catalogs, dependent: :destroy
    has_many :catalogs, through: :product_catalogs
    validates :url, uniqueness: true
end
