require 'nokogiri'
require 'httparty'
require 'byebug'
require 'mechanize'

namespace :scrap do

    desc "Scraping catalogs structure and list of https://www.tohome.com"
    task :catalogs => :environment do
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

    
    # Scraping products. category - list of catalogs
    def scrap_products(category) 
 
        category.each do |element|
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
                        
                        pr_cat = ProductCatalog.new(
                            product_id: pr.id,
                            catalog_id: element.id
                        )
                        pr_cat.save
                         
                        puts "====================================="
                        puts "ID:   #{pr.id}"
                        puts "Name: #{pr.name}" 
                        puts "Price: #{pr.price}"    
                        puts "URL: #{pr.url}"
                        puts "SKU: #{pr.sku}"
                        puts ''
                            
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

    
    # Scraping catalogs
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

            cat_new = Catalog.new(name: "#{cat1_name}", url: "#{cat1_url}", level: "1", parent_url: "https://www.tohome.com")
            cat_new.save

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

                        cat_new = Catalog.new(name: "#{cat2_name}", url: "#{cat2_url}", level: "2", parent_url: "#{cat1_url}")
                        cat_new.save
                    else
                        catalog3 = {
                            name: cat2_name,
                            url: cat2_url,
                            level: 3,
                            parent_url: catalog2[:url]
                        }
                        puts '          ' + catalog3.to_s
                        @catalogs << catalog3

                        cat_new = Catalog.new(name: "#{cat2_name}", url: "#{cat2_url}", level: "3", parent_url: "#{catalog2[:url]}")
                        cat_new.save
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
end