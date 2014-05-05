module FileProductsHelper
	def file_product_html
		style = open(Rails.root.join("app/assets/stylesheets/print/file_product.css"), "rb").read
    style = "<style>#{style}</style>"

    `mkdir #{Rails.root + "tmp/file_products/#{current_user.employee_id}"}` unless File.directory?(Rails.root + "tmp/file_products/#{current_user.employee_id}")
    tmp_path = Rails.root + "tmp/file_products/#{current_user.employee_id}/#{random_string}"
    `mkdir #{tmp_path}`
    concat_files = []

    ["schedule_a", "requirements", "exceptions"].each do |partial|
			html = render partial: "file_products/print_#{partial}"
	    filename = random_string + ".pdf"
	    margin_top    = '0.6in'
	    margin_right  = '0.5in'
	    margin_bottom = '0.6in'
	    margin_left   = '0.5in'

	    case partial
	    when "schedule_a"
	    	header = "#{Rails.root.join("app/views/file_products/schedule_a_header.html")}"
	    	footer = "#{Rails.root.join("app/views/file_products/schedule_a_footer.html")}"
	    	margin_bottom = '2in'
	    when "requirements"
	    	header = "#{Rails.root.join("app/views/file_products/schedule_b_header.html")}"
	    	footer = ""
	    	margin_top = '1in'
	    	margin_bottom = '1.5in'
	    when "exceptions"
	    	header = "#{Rails.root.join("app/views/file_products/schedule_b_header.html")}"
	    	footer = "#{Rails.root.join("app/views/file_products/schedule_b_footer.html")}"
	    	margin_top = '1in'
	    	margin_bottom = '1.5in'
	    end

	    start = 0
	    concat_files.each do |file|
	    	start += (`pdftk #{file} dump_data | grep NumberOfPages`).gsub(/[^0-9]/, "").to_i
	    end

	    pdf = PDFKit.new(style + html, {footer_html: "#{footer}", header_html: "#{header}", title: "#{@file.DisplayFileID}#{"-#{@schedule_a.amended}" unless @schedule_a.amended.blank?}", margin_top:"#{margin_top}", margin_right:"#{margin_right}", margin_bottom:"#{margin_bottom}", margin_left:"#{margin_left}", page_offset: "#{start}", cookie: "company_name=#{@company.CompanyName}**underwriter=#{@schedule_a.underwriter_name}**section=#{partial}"}).to_pdf
	    path = File.expand_path(filename, tmp_path)
	    file = File.new(path, "w+b")
	    file.puts pdf.to_s
	    file.close
	    concat_files << path
	  end

	  image = @file.file_images.where("Imagetype = 'plat' AND Inactive = False AND IsPrivate = False").order("ImageDate DESC").first
	  unless image.nil?
  		path = File.expand_path(random_string + ".pdf", tmp_path)
  		file = DriveMap.posix( image.FullFileName[0] + image.FullFileName[1..-1].downcase)
  		if File.file?(file)
		  	`cp #{file} #{path}`
		  	concat_files << path
		  end
	  end

	  unless @file.underwriter.nil?
	  	["covers\\#{@file.Underwriter}_#{@file.Company}", "underwriter_privacy_policies\\pp#{@file.Underwriter}", "company_privacy_policies\\#{@file.Company}pp"].each do |location|
	  		path = File.expand_path(random_string + ".pdf", tmp_path)
	  		file = DriveMap.posix( "F:\\app\\atom\\#{location}.pdf" )
	  		if File.file?(file)
			  	`cp #{file} #{path}`
			  	concat_files << path
			  end
			end
	  end

	  unless @file_product.type == "Foreclosure Report"
	  	html = render partial: "file_products/print_wiring_instructions"
	    filename = random_string + ".pdf"
	  	margin_top    = '0.5in'
	    margin_right  = '0.5in'
	    margin_bottom = '0.5in'
	    margin_left   = '0.5in'

	    pdf = PDFKit.new(style + html, {margin_top:"#{margin_top}", margin_right:"#{margin_right}", margin_bottom:"#{margin_bottom}", margin_left:"#{margin_left}"}).to_pdf
	    path = File.expand_path(filename, tmp_path)
	    file = File.new(path, "w+b")
	    file.puts pdf.to_s
	    file.close
	    concat_files << path
	  end

	  main_file = random_string + ".pdf"
	  main_path = File.expand_path(main_file, Rails.root + "tmp/file_products/")
	  `pdftk #{concat_files.join(" ")} cat output #{main_path}`
	  `rm -rf #{tmp_path}`
    return main_file
	end

	def amended_options
		collection = []
		10.times do |i|
			collection << ["#{(i + 1).ordinalize} Amended", "#{(i + 1).ordinalize} Amended"]
		end
		return collection
	end

	def land_types
		list = ["Commercial Building", "Commercial Condo", "Commercial Property", "Condo", "Duplex", "Multi-Family Dwelling", "PUD", "Property", "Residence", "Triplex", "Vacant Land"]
		options = []
		list.each do |value|
			options << [value, value]
		end
		return options
	end
end
