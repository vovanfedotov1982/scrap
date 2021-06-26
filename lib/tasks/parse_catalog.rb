require 'nokogiri'
require 'httparty'
require 'byebug'

# Scraping catalogs. Main function
def scrap_catalogs
    url = "https://www.tohome.com"
    catalog_css_target = "div.showCatBtn"
    parsed_list = parse_page(url, catalog_css_target)
    
# Разматываем каталоги
    catalogs_1_count = parsed_list.xpath("//ul[@id='leftnav']/li/a").count
    i = 1 # 1st level catalogs iterator
    
    while i <= catalogs_1_count 
        catalog_1 = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/a")
        catalog_1_url = get_catalog_url(catalog_1)
        catalog_1_name = get_catalog_name(catalog_1_url)
        
        catalog_1_hash = {name: catalog_1_name, url: catalog_1_url, level: 1, parent_url: "https://www.tohome.com"}
        db_record = Catalog.new(name: "#{catalog_1_name}", url: "#{catalog_1_url}", level: "1", parent_url: "https://www.tohome.com")
        db_record.save
        
        puts ''
        puts catalog_1_hash

    # Разматываем подкаталоги
        catalogs_2_lvl_count = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/ul/li/a").count
        catalogs_2_actual = parsed_list.css("a.subject") # Корректный массив каталогов 2 уровня
        j = 1
        while j <= catalogs_2_lvl_count 
        
            # Geting 1st level catalog's attributies  
            begin
                catalog_2 = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/ul/li[#{j}]/a") 
                catalog_2_url = get_catalog_url(catalog_2)
            rescue
            # puts 'i = ' + i.to_s + '; j= ' + j.to_s
            end
            catalog_2_name = get_catalog_name(catalog_2_url)

            # Separating 2nd & 3rd levels catalogs
            begin   
                if catalogs_2_actual.include?(catalog_2[0]) 
                    catalog_2_hash = {name: catalog_2_name, url: catalog_2_url, level: 2, parent_url: catalog_1_url}
                    #puts '    i = ' + i.to_s + '; j = ' + j.to_s + '    ' + catalog2.to_s
                    puts '    ' + catalog_2_hash.to_s

                    db_record = Catalog.new(name: "#{catalog_2_name}", url: "#{catalog_2_url}", level: "2", parent_url: "#{catalog_1_url}")
                    db_record.save
                else
                    catalog_3_hash = {name: catalog_2_name, url: catalog_2_url, level: 3, parent_url: catalog_2_hash[:url]}
                    puts '        ' + catalog_3_hash.to_s

                    db_record = Catalog.new(name: "#{catalog_2_name}", url: "#{catalog_2_url}", level: "3", parent_url: "#{catalog_2_hash[:url]}")
                    db_record.save
                end
            rescue   
                #puts '    i = ' + i.to_s + '; j = ' + j.to_s
                # Steps over missed numbers in catalog's list on the website
                catalogs_2_lvl_count = catalogs_2_lvl_count + 1
            end
            j = j + 1
        end
        i = i + 1
    end
    puts ''
    puts 'Total catalogs added: ' + Catalog.all.count.to_s
    puts 
end


# Returns parsed list which is in "css_object"
def parse_page(url, css_target)
    page = HTTParty.get(url)
    parsed_page = Nokogiri::HTML(page.body)
    parsed_list = parsed_page.css(css_target) 
    return parsed_list
end

# Extracts url from xptath
def get_catalog_url(xpath)
    url = xpath[0].attributes["href"].value
    return url
end

# Extracts catalog's name from url
def get_catalog_name(catalog_url)
    if catalog_url.to_s.include?("catalog_name=")
        catalog_name = catalog_url.split("catalog_name=").last&.gsub("-", " ") #вытаскиваем Название из URL; & перед gsub чтоб ошибку не выдавало
    elsif catalog_url.to_s.include?('?PFDID')
        catalog_name = catalog_url.gsub('?', '').gsub(/PFDID.*/, "").split("/").last.gsub("-", " ")     #
    elsif catalog_url.to_s.include?('&PFDID1')
        catalog_name = catalog_url.split('&').first
    elsif catalog_url.to_s.include?('?page=1') 
        catalog_name = catalog_url.gsub('?', '').gsub(/page=1.*/, "").split("/").last
    elsif catalog_url.to_s.include?('/catalog/')
        catalog_name = catalog_url.split("/").last&.gsub("-", " ")
    else
        catalog_name = catalog_url.split("/").last
    end
    return catalog_name
end
