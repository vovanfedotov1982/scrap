require_relative 'parse_catalog.rb'
require_relative 'parse_product.rb'

namespace :scrap do

    desc "Scraping catalogs structure and list of https://www.tohome.com"
    task :catalogs => :environment do
        ProductCatalog.delete_all 
        Catalog.delete_all
        scrap_catalogs
    end

    desc "Scraping products in catalog list which is parameter"
    task :products => :environment do
        ProductCatalog.delete_all 
        Product.delete_all
        scrap_products(Catalog.all)
    end

    desc "Scraping Caatalogs & Products"
    task :all => [:catalogs, :products]

    task :testing => :environment do
        #del = Product.find(116)
        #del.destroy
    end

end