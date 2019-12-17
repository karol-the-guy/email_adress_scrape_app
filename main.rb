require 'nokogiri'
require 'open-uri'
require 'watir'
require 'colorize'
require 'byebug'
require 'csv'

module EmailScrape
	GOOGLE_URL = 'https://google.com'
	EMAIL_REGEX = /\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}\b/
	PHONE_REGEX = /\(?[0-9]{3}[\-\)][0-?9]{3}-[0-9]{3}/
	PHONE_REGEX_1 = /[1-9](\d{2}){4}$/
	@sites_urls_from_serp = []
	@sites_to_email_scrape = []
	@emails = []

	extend self
	attr_reader :phrase, :amount_of_tabs, :site_links_limit

	def call
		begin
			print "How many SERP's you want to scrape? (Leave empty to default 5): "
			@amount_of_tabs = (input = gets.chomp).empty? ? 5 : input.to_i
			raise "You should define number between 1-50" if @amount_of_tabs < 1 || @amount_of_tabs > 50
		rescue => e
			puts e.message.red
			retry
		end

		begin
			print "How meny links from every site should be checked for email? (Leave empty for default value: 15): "
			@site_links_limit = (input = gets.chomp).empty? ? 15 : input.to_i - 1
			raise "You should type number between 1-250" if @site_links_limit < 0 || @site_links_limit > 250
		rescue => e
			puts e.message.red
			retry
		end

		begin
			print 'Input searched phrase which you want to scrape email for: '
			@phrase = gets.chomp
			raise "Search phrase should be longer. Try again!" if @phrase.length < 3
		rescue => e
			puts e.message.red
			retry
		end
		perform
	end

	private

	def perform
		perform_search
		parse_search_html
		find_links_from_search
		click_next_serp
		find_emails
	end

	def perform_search
		begin
			@browser = Watir::Browser.new(:chrome) # :headless_chrome
			@browser.goto(GOOGLE_URL)
			@browser.text_field(title: "Szukaj").set "#{@phrase}"
			@browser.send_keys :enter
		rescue Watir::Exception::UnknownObjectException => e
			puts e.message.red
			@browser.text_field(title: "Search").set "#{@phrase}"
			@browser.send_keys :enter
		end
	end

	def parse_search_html
		@google_search = Nokogiri::HTML.parse(@browser.html)
	end

	def find_links_from_search
		@sites_urls_from_serp << @google_search.css("div.r > a").css('a')&.collect { |a| a.attr('href') } rescue "Collecting urls from serp failed"
	end

	def click_next_serp
		until @amount_of_tabs == 1 do
			begin
				@browser.link(text: "Następna").click
			rescue Watir::Exception::UnknownObjectException => e
				puts e.message.red
				@browser.link(text: "Next").click
			end

			parse_search_html
			find_links_from_search
			@amount_of_tabs -= 1
		end
		find_first_child_links_on_each_site
	end

	def find_first_child_links_on_each_site
		@sites_urls_from_serp.flatten! && @sites_urls_from_serp.uniq!

		@sites_urls_from_serp.each do |url|
			begin
				print "#{url} \n".blue
		  		site = Nokogiri::HTML(open(url))
		  		@hrefs = site.css("a")&.map do |link|
					if (href = link.attr("href")) && !href.empty?
						URI::join(url, href)
					end
				end
			rescue => e
				puts "#{e.message.red} \n"
			end

			urls = @hrefs&.map { |uri| uri.to_s if uri.to_s.include?(url_pattern(url)) }&.compact
			@sites_to_email_scrape << urls&.uniq&.slice(0..@site_links_limit)
		end
		@sites_to_email_scrape.flatten! && @sites_to_email_scrape.uniq!
		print "Found #{@sites_to_email_scrape.count} sites to scrape emails from! \n".green
	end

	def url_pattern(url)
		pattern = url.sub(/^http[s]?\:\/\//, '').sub(/^www/,'')
		pattern.slice 0..6
	end

	def find_emails
    	@sites_to_email_scrape.each do |site|
    		print "#{site} \n"
    		begin
    			@browser.goto(site)
    			find_emails_in_html
    		rescue => e
    			puts "#{e.message.red} \n"
    		end
    	end
    	emails = @emails.reject(&:empty?).compact.uniq
			puts "*-|-*" * 10
			export_to_txt(emails) until emails.empty?
    	puts "Found #{emails.count} e-mails! \n".green
  	end

	def find_emails_in_html
		begin
			contact_info = @browser.html.scan(EMAIL_REGEX).uniq
			unless contact_info.empty?
				contact_info.unshift(@browser.url) unless contact_info.empty?
				# contact_info << @browser.html.scan(PHONE_REGEX).uniq
				# contact_info << @browser.html.scan(PHONE_REGEX_1).uniq
				contact_info.flatten!
			end
			@emails << contact_info
			print "Site scraped! \n".green
		rescue => e
			puts "#{e.message.red} \n"
		end
	end

	def export_to_txt(emails)
		begin
			file = File.new("emails-#{@phrase}-#{Time.now.strftime("%d-%m-%Y")}.txt", "w")
			file << emails
			file.close
			puts ".txt file created successfully!".green
			exit
		rescue => e
			puts ".txt failed, error: #{e.message}".red
			puts emails
			exit
		end
	end
end

EmailScrape.call
