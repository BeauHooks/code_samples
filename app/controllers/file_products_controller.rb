class FileProductsController < ApplicationController
  respond_to :html, :js, :json
  before_filter :set_options, :set_field, :only => [:review, :display_search_results, :result_detail]

  def index

  end

  def show
    @file_product = FileProduct.find(params[:id])
    load_vars()

    # Setup Rate Calculator
    @rate_calculation = RateCalculation.initialize_from_file(@file_product.file_id, current_user.employee_id, @file_product.product_type.name, "pr") if @rate_calculation.nil?
    @rate_calculation.save!
    @rate_calculation.calculate!

    respond_to do |format|
      format.js
    end
  end

  def create
    @file = Index.where("FileID = #{params[:file_id]}").first

    if @file.file_products.where("product_type_id = '#{params[:product_type_id]}' AND is_active = -1").first != nil
      render js: "addToQueue('file_product_exists', 'application/flash_notice?notice=Product already exists for this file. Please select the product you want to edit in the list.');"
    else
      @file_product                 = FileProduct.new
      @file_product.file_id         = params[:file_id]
      @file_product.product_type_id = params[:product_type_id]
      @file_product.is_active       = -1
      @file_product.is_locked       = 0
      @file_product.created_by      = current_user.employee_id
      @file_product.updated_by      = current_user.employee_id
      @file_product.save
      load_vars

      respond_to do |format|
        format.js {render "show"}
      end
    end
  end

  def update
    @file_product = FileProduct.find(params[:id])
  end

  def show_options
    unless params[:Company].blank? || params[:DisplayFileID].blank?
      @file = Index.where("Company = #{params[:Company]} AND DisplayFileID = '#{params[:DisplayFileID]}' #{Index.can_view(current_user, session[:company])}").first

      unless @file.nil?
        respond_to do |format|
          format.js
        end
      else
        render js: "addToQueue('show_options_error', 'application/flash_notice?title=Error&notice=Your search returned 0 results. Please review your criteria and try again.');"
      end
    else
      render nothing: true
    end
  end

  # def view_history
  #   if params[:datetime].blank?
  #     render nothing: true
  #     return
  #   end

  #   @datetime = datetime_parse(params[:datetime])
  #   @file_product = FileProduct.find params[:id]
  #   load_vars()
  #   respond_to do |format|
  #     format.js {render "show"}
  #   end
  # end

	def print
    @file_product = FileProduct.find(params[:id])
    load_vars()

		@logo = DriveMap.posix(@company.CompanyLogo)
		closer = @file.closers.size > 0 ? @file.closers.first.employee : nil
		@office = closer != nil ? closer.office : nil

    respond_to do |format|
      format.js
    end
  end

  def review
    if params[:search]
      @search_results = Index.search(params[:search_field],params[:search])
      @search_results = @search_results.file_products
      if params[:match] || params[:search_field] == "file_id"
        @match = set_match
      end
    else
      @search_results = nil
    end
    @detail = set_detail
    @search_results
  end

  def display_search_results
    @search_results = Index.search(params[:search_field],params[:search])
    @search_results = @search_results.file_products
    if params[:match] || params[:search_field] == "file_id"
      @match = set_match
    end
    @detail = set_detail
    @search_results
  end

  def display # for print
    filename = params[:content]
    path     = File.expand_path(filename, Rails.root + "tmp/file_products/")
    send_file(path, filename: "file_product.pdf", disposition: "inline")
  end

  def new_import
    @file_product = FileProduct.find params[:id]
    @type = params[:type]
  end

  def get_prior_product_options
    if params[:prior_file_number].blank?
      return
    end

    @prior = Index.where("DisplayFileID = '#{params[:prior_file_number]}' AND Company = #{params[:company_id]}").first

    if @prior.nil?
      render js: "addToQueue('get_prior_error', 'application/flash_notice?title=Error&notice=The prior you searched for does not exist. Please review your inputs and try again.');"
      return
    end

    if @prior.file_product_collection.size > 0
      @file_products, @collection_type =  @prior.file_product_collection, "new"
    else
      @file_products, @collection_type =  @prior.old_file_product_collection, "old"
    end

    if @file_products.size == 0
      render js: "addToQueue('get_prior_error', 'application/flash_notice?title=Error&notice=The prior you searched for does not contain any products from which to import. Please review your inputs and try again.');"
    end
  end

  def import
    file_product = FileProduct.find params[:id]
    (file_product.policies + file_product.policy_endorsements + file_product.fp_requirements + file_product.fp_exceptions).each do |child|
      child.removed_by = current_user.employee_id
      child.removed_at = Time.now.to_s(:db)
      child.save
    end

    case params[:type]
    when "prior"
      params[:collection_type] == "new" ? file_product.import_prior(params[:prior_file_product_id], current_user) : file_product.import_old_prior(params[:prior_file_product_id], current_user)
    when "base"
      base = BaseFile.where("subsurvey = '#{params[:subsurvey]}' #{params[:phase].blank? ? "AND phase IS NULL" : "AND phase = '#{params[:phase]}'"}").first
      unless base.nil?
        file_product.import_base(base.id, current_user)
      else
        base = FileBase.where("Subsurvey = '#{params[:subsurvey]}' #{params[:phase].blank? ? "AND Phase = ''" : "AND Phase = '#{params[:phase]}'"}").first

        if base.nil?
          render js: "$('#import_spinner').hide(); addToQueue('get_base_error', 'application/flash_notice?title=Error&notice=The base you searched for does not exist. Please review your inputs and try again.');"
          return
        else
          file_product.import_old_base(base.BaseID, current_user)
        end
      end
    end

    @file_product = FileProduct.find params[:id]
    load_vars()
    respond_to do |format|
      format.js {render "show"}
    end
  end

  def helper
    unless params[:Shortcut].blank?
      response = Alth.where("Shortcut = '#{params[:Shortcut]}'").first.Response rescue nil
    end

    if response.blank?
      render js: "addToQueue('shortcut_error', 'application/flash_notice?title=Shortcut Error&notice=The shortcut you entered does not exist. Please try again.'); closeOverlay('helper'); closeOverlay('helper_info');"
    end

    @container = params[:container]
    @response = response
    @start = params[:start]
    @end = params[:end]
  end

  def input_helper
    @container = params[:container]
    @start = params[:start]
    @end = params[:end]
  end

  private

    def result_detail
      @detail = set_detail
    end

    def set_match
      if params[:id]
        Index.find(params[:id])
      else
        nil
      end
    end

    def set_detail
      if params[:id]
        Index.find(params[:id])
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
        @search_field = 'file_id'
      end
    end

    def set_options
      @select_options = FileProduct::SELECT_OPTIONS
      @search_display = FileProduct::SEARCH_DISPLAY
      @show_county = false
      @page = params[:page] ||= 1
      @page = @page.to_i
    end

    def load_vars
      @file             = @file_product.index
      @company          = @file.company
      @schedule_a       = @file_product.schedule_a(@datetime)
    end

end
