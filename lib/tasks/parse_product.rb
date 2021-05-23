require 'nokogiri'
require 'httparty'
require 'byebug'

class ParseProduct

    # Get & save product, print details
    # prod - pagination product card
    # element - record of the catalog in table "Catalogs"
    def self.get_and_save_product(prod, element)
        u = prod.css('a')[0].attributes['href'].value #url товара
        pr_sku = u.split("&product_name=")[0].split("product_id=")[1] #вытаскиваем SKU из URL
        pr_name = prod.css('h2.prdTitle').text
        pr_price = prod.css('span.prdPrice-new').text.gsub(',','').scan(/\d+/).join
        pr_url = 'https:' + u
        if pr_url.include?('https:.')
            pr_url = pr_url.gsub('https:.','https://www.tohome.com')
        end
        
        pr = Product.find_or_create_by(url: pr_url)
            pr.name = pr_name
            pr.price = pr_price
            pr.url = pr_url
            pr.sku = pr_sku
        pr.save # we save the product in DB  
        pr.catalogs << element # ключи в связующей таблице
        puts "====================================="
        puts "ID:   #{pr.id}"
        puts "Name: #{pr.name}" 
        puts "Price: #{pr.price}"    
        puts "URL: #{pr.url}"
        puts "SKU: #{pr.sku}"
        puts ''
    end

    # Scraping products.
    # category - list of catalogs, records of table "Catalogs"
    def self.scrap_products(category_records) 
 
        category_records.each do |element|
            puts '==============='
            puts element.name
            puts element.url
            puts '==============='
                
            begin
                page = HTTParty.get(element.url)
                parsed_page = Nokogiri::HTML(page.body)
                prod_card_list = parsed_page.css('div.mainbox')

                i = 1
                pr_count = 0 
                items_in_category = parsed_page.css('span#lblCount').text.split(' ')[5].to_i
                items_per_page = prod_card_list.count
                total_pages = (items_in_category.to_f / items_per_page.to_f).ceil #страниц с товарами

                while i <= total_pages 
                    pagination_url = element.url.gsub('catalog.aspx?catalog_id=', 'catalog/').gsub('&catalog_name=','/') + "/?page=#{i}&sort=2"
                    puts "***************************************"
                    puts "Page #: #{i}   " + pagination_url
                    puts "***************************************"

                    pagination_page = HTTParty.get(pagination_url)
                    pagination_parsed_page = Nokogiri::HTML(pagination_page.body)
                    pagination_prod_card_list = pagination_parsed_page.css('div.mainbox')
                                    
                    # Перебираем продукты на странице
                    pagination_prod_card_list.each do |prod|       
                        get_and_save_product(prod, element)
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

end
