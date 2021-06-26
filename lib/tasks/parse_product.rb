require 'nokogiri'
require 'httparty'
require 'byebug'
require_relative 'parse_product.rb'

# Scraping products. Main function
# category_records - list of catalogs, records of table "Catalogs"
def scrap_products(category_records) 
    category_records.each do |element|
        print_catalog_details(element)
        
        begin
            product_css_target = "div.mainbox"
            items_in_category_css_target = "span#lblCount"
            
            prod_card_list = parse_page(element.url, product_css_target)

            i = 1 # page iterator
            pr_count = 0 

            items_in_category = parse_page(element.url, items_in_category_css_target).text.split(' ')[5].to_i
            items_per_page = prod_card_list.count
            total_pages = (items_in_category.to_f / items_per_page.to_f).ceil #страниц с товарами
            
            while i <= total_pages 
                pagination_url = element.url.gsub('catalog.aspx?catalog_id=', 'catalog/').gsub('&catalog_name=','/') + "/?page=#{i}&sort=2"
                
                print_pagination_details(i, pagination_url)
                
                pagination_prod_card_list = parse_page(pagination_url, product_css_target)
                                
                # Перебираем продукты на странице
                pagination_prod_card_list.each do |prod|       
                    
                    db_record_product = Product.find_or_create_by(url: get_product_url(prod))
                        db_record_product.name = get_product_name(prod)
                        db_record_product.price = get_product_price(prod)
                        db_record_product.url = get_product_url(prod)
                        db_record_product.sku = get_product_sku(prod)
                    db_record_product.save # save the product in DB  
                    
                    db_record_product.catalogs << element # ключи в связующей таблице
                    
                    print_product_attr(db_record_product) 
                end
                i = i + 1
                pr_count = pr_count + pagination_prod_card_list.count # счетчик товаров в категории
            end 
            puts "Added items to category: " + pr_count.to_s
            puts "Total added: "  + Product.all.count.to_s
            puts'' 
        rescue
            puts "!!! This catalog is empty"
            puts ''
            next
        end
    end
end

# Helper functions
def get_product_url(product)
    url = 'https:' + product.css('a')[0].attributes['href'].value #url товара
    if url.include?('https:.')
        url = url.gsub('https:.','https://www.tohome.com')
    end
    return url
end

def get_product_sku(product)
    product_url = get_product_url(product)
    sku = product_url.split("&product_name=")[0].split("product_id=")[1] #вытаскиваем SKU из URL
    return sku
end

def get_product_name(product)
    name = product.css('h2.prdTitle').text
    return name
end

def get_product_price(product)
    price = product.css('span.prdPrice-new').text.gsub(',','').scan(/\d+/).join
    return price
end

def print_catalog_details(table_record)
    puts '==============='
    puts table_record.name
    puts table_record.url
    puts '==============='
end

def print_pagination_details(i, pagination_url)
    puts "***************************************"
    puts "Page #: #{i}   " + pagination_url
    puts "***************************************"
end

def print_product_attr(db_record_product)
    puts "====================================="
    puts "ID:   #{db_record_product.id}"
    puts "Name: #{db_record_product.name}" 
    puts "Price: #{db_record_product.price}"    
    puts "URL: #{db_record_product.url}"
    puts "SKU: #{db_record_product.sku}"
    puts ''
end