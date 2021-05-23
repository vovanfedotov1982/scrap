require 'nokogiri'
require 'httparty'
require 'byebug'

class ParseCatalog

    def self.get_cat2_name (cat2_url)
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
        return cat2_name
    end

    # Scraping catalogs
    def self.scrap_catalogs
        url = "https://www.tohome.com"
        page = HTTParty.get(url)
        parsed_page = Nokogiri::HTML(page.body)
        parsed_list = parsed_page.css("div.showCatBtn") 
    # Разматываем каталоги
        cat1_count = parsed_list.xpath("//ul[@id='leftnav']/li/a").count
        i = 1
        while i <= cat1_count 
            cat1 = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/a")
            cat1_url = cat1[0].attributes["href"].value
            cat1_name = cat1_url.split("catalog_name=")[1]&.gsub("-", " ") #вытаскиваем Название из URL; & перед gsub чтоб ошибку не выдавало
            catalog1 = {name: cat1_name, url: cat1_url, level: 1, parent_url: nil}
            puts ''
            puts catalog1
            
            cat_new = Catalog.new(name: "#{cat1_name}", url: "#{cat1_url}", level: "1", parent_url: "https://www.tohome.com")
            cat_new.save

    # Разматываем подкаталоги
            cat2_count = parsed_list.xpath("//ul[@id='leftnav']/li[#{i}]/ul/li/a").count
            cat2_subj = parsed_list.css("a.subject") # Корректный массив каталогов 2 уровня
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
                cat2_name = ParseCatalog.get_cat2_name(cat2_url)

                # Разделяем каталоги 2 и 3 уровн
                begin   
                    if cat2_subj.include?(cat2[0]) 
                        catalog2 = {name: cat2_name, url: cat2_url, level: 2, parent_url: cat1_url}
                        #puts '    i = ' + i.to_s + '; j = ' + j.to_s + '    ' + catalog2.to_s
                        puts '    ' + catalog2.to_s

                        cat_new = Catalog.new(name: "#{cat2_name}", url: "#{cat2_url}", level: "2", parent_url: "#{cat1_url}")
                        cat_new.save
                    else
                        catalog3 = {name: cat2_name, url: cat2_url, level: 3, parent_url: catalog2[:url]}
                        puts '        ' + catalog3.to_s

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
        puts 'Total catalogs added: ' + Catalog.all.count.to_s
        puts 
    end
end