require 'nokogiri'
require 'httparty'
require 'byebug'
require 'mechanize'



def scrap_catalogs
    url = "https://www.tohome.com"
    page = HTTParty.get(url)
    parsed_page = Nokogiri::HTML(page.body)
    parsed_list = parsed_page.css("div.showCatBtn") 
# Разматываем каталоги
    cat1_count = parsed_list.xpath("//ul[@id='leftnav']/li/a").count
    @catalogs = Array.new
    i = 1
    while i <= cat1_count 
        cat1 = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/a")
        cat1_url = cat1[0].attributes["href"].value
        cat1_name = cat1_url.split("catalog_name=")[1]&.gsub("-", " ") #вытаскиваем Название из URL; & перед gsub чтоб ошибку не выдавало
        catalog1 = {
            name: cat1_name,
            url: cat1_url,
            level: 1,
            parent_url: nil
        }
        puts ''
        puts catalog1
        @catalogs << catalog1
# Разматываем подкаталоги
        cat2_count = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/ul/li/a").count
        cat2_subj = parsed_list.css("a.subject") # Корректный сассив каталогов 2 уровня
        j = 1
        while j <= cat2_count 
            # Catalog URL 
            begin
                cat2 = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/ul/li[#{j}]/a")
                cat2_url = cat2[0].attributes['href'].value
            rescue
               # puts 'i = ' + i.to_s + '; j= ' + j.to_s
            end
            # Catalog name
            if cat2_url.to_s.include?("catalog_name=")
                cat2_name = cat2_url.split("catalog_name=").last&.gsub("-", " ") #вытаскиваем Название из URL; & перед gsub чтоб ошибку не выдавало
            elsif cat2_url.to_s.include?('?PFDID')
                cat2_name = cat2_url.gsub('?', '').gsub(/PFDID.*/, "").split("/").last.gsub("-", " ")     #
            elsif cat2_url.to_s.include?('&PFDID1')
                cat2_name = cat2_url.split('&').first
            elsif cat2_url.to_s.include?('?page=1') 
                cat2_name = cat2_url.gsub('?', '').gsub(/page=1.*/, "").split("/").last
            elsif cat2_url.to_s.include?('/catalog/')
                cat2_name = cat2_url.split("/").last&.gsub("-", " ")
            else
                cat2_name = cat2_url.split("/").last
            end
            # Разделяем каталоги 2 и 3 уровн
            begin   
                if cat2_subj.include?(cat2[0]) 
                    catalog2 = {
                        name: cat2_name,
                        url: cat2_url,
                        level: 2,
                        parent_url: cat1_url
                    }
                    #puts '    i = ' + i.to_s + '; j = ' + j.to_s + '    ' + catalog2.to_s
                    puts '     ' + catalog2.to_s
                    @catalogs << catalog2
                else
                    catalog3 = {
                        name: cat2_name,
                        url: cat2_url,
                        level: 3,
                        parent_url: catalog2[:url]
                    }
                    # puts '    i = ' + i.to_s + '; j = ' + j.to_s + '        ' + catalog3.to_s
                    puts '          ' + catalog3.to_s
                    @catalogs << catalog3
                end
            rescue   
                #puts '    i = ' + i.to_s + '; j = ' + j.to_s
                cat2_count = cat2_count + 1
            end
            j = j + 1
        end
        i = i + 1
    end
    puts ''
    puts 'Total catalogs added: ' + @catalogs.count.to_s
    puts @catalogs.uniq.count
end


# Парсим продукты из массива категорий. category - массив категорий определенного уровня
def products_in_category(category) 

    array_products = Array.new
    
    category.each_with_index do |element, index|
        puts element

        element.each do |key, value|
            if key == :url  
                #puts value # выводит значение value если ключ == :url
                begin
                    page = HTTParty.get(value)
                    parsed_page = Nokogiri::HTML(page.body)
                    prod_card_list = parsed_page.css('div.mainbox')

                    #products = Array.new
                    i = 1 
                    pr = 0 
                    items_in_category = parsed_page.css('span#lblCount').text.split(' ')[5].to_i
                    items_per_page = prod_card_list.count
                    total_pages = (items_in_category.to_f / items_per_page.to_f).ceil #страниц с товарами
                    
                    while i <= total_pages 

                        

                        pagination_url = value.gsub('catalog.aspx?catalog_id=', 'catalog/').gsub('&catalog_name=','/') + "/?page=#{i}&sort=2"
                        #puts pagination_url
                        puts "***************************************"
                        puts "Page #: #{i}   " + pagination_url
                        puts "***************************************"
                        pagination_page = HTTParty.get(pagination_url)
                        pagination_parsed_page = Nokogiri::HTML(pagination_page.body)
                        pagination_prod_card_list = pagination_parsed_page.css('div.mainbox')

                        # Перебираем продукты на странице
                        
                        pagination_prod_card_list.each do |prod|       
                            
                            u = prod.css('a')[0].attributes['href'].value #url товара
                            prod_id = u.split("&product_name=")[0].split("product_id=")[1] #вытаскиваем SKU из URL
                        
                            product = { 
                                #sku: prod.css('div.catalogCard-code').text.gsub("Артикул: ", ""),
                                name: prod.css('h2.prdTitle').text,
                                price: prod.css('span.prdPrice-new').text.gsub(',','').scan(/\d+/).join,
                                url: 'https:' + prod.css('a')[0].attributes['href'].value,
                                sku: prod_id,
                                #cat_id: index,
                                #cat_name: element[:name],
                                #cat_url: element [:url]

                            }
                            
                            array_products << product    
                            puts "====================================="
                            puts "Name: #{product[:name]}"
                            puts "Price: #{product[:price]}"    
                            puts "URL: #{product[:url]}"
                            puts "SKU: #{product[:sku]}"
                           # puts "Cat_ID: #{product[:cat_id]}"
                           # puts "Cat Name: #{product[:cat_name]}"
                           # puts "Parent URL: #{product[:cat_url]}"

                            puts ''
                                
                        end
                        i = i + 1
                        pr = pr + pagination_prod_card_list.count # счетчик товаров в категории
                    # byebug
                    end 

                    puts "Added items to category: " + pr.to_s
                    puts "Total added: "  + array_products.count.to_s
                    puts'' 
                
                rescue
                    puts "!!! This catalog is empty"
                    puts ''
                    next
                end
            end
        end   
        #byebug
    end
    return array_products
end

#scrap_catalogs
#products_in_category(@catalogs)

scrap_test