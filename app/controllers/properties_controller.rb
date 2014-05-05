class PropertiesController < ApplicationController
  require 'RMagick'
  include Magick
  respond_to :html, :js, :json
  before_filter :set_county, :set_options, :set_field

  def index
    if params[:search]
      @search_results = Taxroll2.search(params[:search_field],@county_id,params[:search])
    else
      @search_results = nil
    end
    @detail = set_detail
    respond_with @search_results
  end

  def display_search_results
    @search_results = Taxroll2.search(params[:search_field],@county_id,params[:search])
    @detail = set_detail
  end

  def result_detail
    @detail = set_detail
  end

  def generate_pdf
    company  = Company.find session[:company]
    property = Taxroll2.find params[:id]

    respond_with {
      html = render_to_string(template: "properties/templates/pdf.html", layout: false, locals: {property: property, company: company})
      kit = PDFKit.new(html, {footer_html: "#{join("app", "views", "properties", "templates", "property_profile_footer.html")}", margin_bottom: "0.85in", margin_top: "0.85in", margin_right: "0.5in", margin_left: "0.5in", cookie: "company_name=#{company.CompanyName}**company_phone=#{company.CompanyPhone}"})
      kit.stylesheets << Rails.root.join("app","assets","stylesheets","pdf.css")
      send_data(kit.to_pdf, :filename => "property.pdf", :type => 'application/pdf')
      return
    }
  end

  def images
    # Accepted Types: Photo, Sketch
    image = TaxrollImages.where("AccountNum = '#{params[:account]}' AND ImageType = '#{params[:type]}'").first

    if !image.nil?
      file  = File.join(DriveMap.posix(image.BaseDir), image.FileName)
      if Pathname.new(file).exist?
        send_file file, :disposition => 'inline'
      else
        send_file Rails.root.join("app","assets","images","no_image_available.jpg"), :disposition => 'inline'
      end
    else
      send_file Rails.root.join("app","assets","images","no_image_available.jpg"), :disposition => 'inline'
    end
  end

  def plat
    property = Taxroll1.where("accountnum = '#{params[:account]}'").first
    file     = File.join(DriveMap.map("f") + "/images/taxid/" + property.serialnum.split("-").first.downcase + "/" + property.serialnum + ".TIF")

    if Pathname.new(file).exist?
      jpg = Magick::Image.read(file).first.to_blob { self.format = "JPEG"}
      send_data jpg, :filename => "image.jpg", :disposition => 'inline'
    else
      send_file Rails.root.join("app","assets","images","no_image_available.jpg"), :disposition => 'inline'
    end
  end

  def set_detail
    if params[:id]
      Taxroll2.find(params[:id])
    else
      unless @search_results.blank?
        @search_results.first
      else
        nil
      end
    end
  end

  def set_field
    if params[:search_field]
      @search_field = params[:search_field]
    else
      @search_field = 'OwnerName'
    end
  end

  def set_county
    if params[:county_id]
      @county_id = params[:county_id]
    else
      @county_id = current_user.county ||= 4 # Washington County
    end
  end

  def set_options
    @select_options = Taxroll2::SELECT_OPTIONS
    @search_display = Taxroll2::SEARCH_DISPLAY
  end
end
