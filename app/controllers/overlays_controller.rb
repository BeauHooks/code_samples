class OverlaysController < ApplicationController
  respond_to :json
  before_filter :identifier
  layout "overlay"

  def payment_disbursement_info
    @buttons = ["close"]
  end

  def confirm_payment_change
    @payment_disbursement = PaymentDisbursement.find params[:id]
    @payment_params = params[:payment_disbursement]
    @view = params[:view]
    @buttons = ['save', 'cancel']
  end

  def confirm_destroy_check_working
    @disbursement = CheckWorking.find params[:id]
    @buttons = ["continue", "cancel"]
  end

  def merge_disbursements
    @file = Index.find params[:id]
    @buttons = ['save', 'cancel']
  end

  def balance_sheet
    @file = Index.find(params[:id])
    @buttons = ["close"]
  end

  def change_line_type
    @line = SsLine.find params[:id]
    @buttons = ['save', 'cancel']
  end

  def insert_line
    @line = SsLine.find params[:id]
    @where = params[:where]
    @buttons = ['save', 'cancel']
  end

  def cell_attributes
    @cell = SsLineCell.find params[:id]
    @buttons = ['save', 'cancel']
  end

  def new_site_preference
    @preference = SitePreference.new
    @buttons = ['save', 'cancel']
  end

  def new_rule
    @rule = Rule.new
    @buttons = ['save', 'cancel']
  end

  def new_file_note
    @file = Index.find(params[:id])
    @buttons = ['save', 'cancel']
  end

  def new_entity_note
    @rolodex_entity = Entity.find(params[:id])
    @buttons = ['save', 'cancel']
  end

  def new_entity_contact
    @rolodex_entity = Entity.find(params[:id])
    @buttons = ['save', 'cancel']
  end

  def new_entity
    @entity = Entity.new
    @buttons = ['save', 'cancel']
  end

  def file_entities
    @file = Index.includes(:file_entities).find(params[:id]) if params[:id]
    @buttons = ["close"]
  end

  def new_user
    @user = User.new
    @buttons = ['save', 'cancel']
  end

  def doc_groups
  end

  def new_doc_group
    @buttons = ['save']
  end

  def add_to_doc_group
    @group = DocGroup.find params[:id]
  end

  def bug_report
    @buttons = ['send']
  end

  def feature_request
    @buttons = ['send']
  end

  def choose_doc_entity
    @template = DocTemplate.find params[:template]
    if @template != nil
      @file   = Index.where("FileID = #{params[:file_id]}").first
      @doc_id = 0
    else
      render nothing: true
    end
    @buttons = ["save", "cancel"]
  end

  def choose_side
    @action = "#{params[:href]}"
    params[:only_hud] ? @only_hud = true : @only_hud = false
    params[:docs].each do |d|
      @action += "&docs[]=#{d}"
    end

    @buttons = ["continue", "cancel"]
  end

  def edit_address
    @file = Index.find params[:file_id]
    @tag = params[:tag].upcase
    @address = ["", "", "", "", "", ""]
  end

  def manage_signature_block
    @doc_entity     = FileDocEntity.find params[:id]
    @rolodex_entity = Entity.find @doc_entity.entity_id
    @signature      = RolodexSignature.find @doc_entity.rolodex_signature_id
    @file = Index.where("FileID = #{@doc_entity.file_id}").first
  end

  def manage_signatures
    @doc = Doc.find params[:id]
    @file = @doc.index
  end

  def doc_lookup
    @file = Index.find(params[:file_id])
    @buttons = ["close"]
  end

  def add_affiliations
    @entity = Entity.find params[:id]
    @affiliations = []
    @buttons = ['close']
  end


  def show_resend_confirmation
    @file = Index.find params[:id]
    @buttons = ['send', 'cancel']
  end

  def new_order
    if params[:file_id]
      @file = Index.find(params[:file_id])
    else
      in_progress = Index.in_progress(current_user.employee_id)
      in_progress.destroy if in_progress
      @file = Index.create(OrderTakenBy: current_user.employee_id, Company: session[:company])
      @file.file_employees.create
    end
    @counties          = County.find(:all, order: "CountyName ASC")
    @default_county    = Company.find(session[:company]).DefaultCounty
    @underwriters      = Underwriter.where("IsActive = -1").order("Underwriter ASC")
    @transaction_types = TransactionType.all
    @employees         = Employee.closers(session[:company], @permission_lock_files)
    if @permission_lock_files
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Opened Order')")
    else
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Searcher', 'Opened Order')")
    end
    @buttons = ['save', 'save_and_copy', 'cancel']
  end

  def add_file_entities_new_order
    @buttons = ["close"]
  end

  def file_properties
    @file = Index.find(params[:file_id]) if params[:file_id]
    if @search_value != nil && @search_value != ""
      @properties = Taxroll1.find(:all, conditions: "taxroll1.accountnum LIKE '%#{@search_value}%' OR taxroll1.serialnum LIKE '%#{@search_value}%' OR taxroll1.SitusAddress LIKE '%#{@search_value}%' OR taxroll2.FullLegal LIKE '%#{@search_value}%'", limit: "50", order: "taxroll1.serialnum", include: "taxroll2")
    else
      @properties = []
    end
    @buttons = ['close']
  end

  def close_note
    @file = Index.find params[:id]
    @buttons = ['cancel', 'continue']
  end

  def cpl
    @file = Index.find params[:id]
    if @file.closing_protection_letters.empty?
      @cpl = ClosingProtectionLetter.new(file: @file, company_id: @file.Company)
      @cpl.cpl_gather_data(@file)
    else
      @cpl = @file.closing_protection_letters.last
      @cpl.cpl_update_data(@cpl.file)
    end
    @buttons = ['close']
  end

  def cpl_new
    @file = Index.find params[:id]
    @cpl = ClosingProtectionLetter.new(file: @file, company_id: @file.Company)
    @cpl.cpl_gather_data(@file)
    @buttons = ['close']
  end

  def cpl_show
    @cpl = ClosingProtectionLetter.find(params[:id])
    @file = @cpl.file
    @buttons = ['close']
  end

  def fatco_rate_request
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.fatco_rate_request
    raise response.inspect
  end

  def cpl_request
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.submit_cpl_order
    @cpl.parse_order_response(response,current_user)
    @cpl.save_cpl_pdf(response,random_string)
  end

  def cpl_cancel
    @cpl = ClosingProtectionLetter.find(params[:id])
    if @cpl.cpl_sent?
      response = @cpl.cancel_cpl
      @cpl.parse_cancel_response(response,current_user)
    else
      @cpl.update_attributes(cpl_status: "Canceled", updated_by: current_user)
    end
    @file = @cpl.file
    @buttons = ['close']
  end

  def cpl_close
    @cpl = ClosingProtectionLetter.find(params[:id])
    if @cpl.cpl_sent?
      response = @cpl.close_cpl
      @cpl.parse_close_response(response,current_user)
    else
      @cpl.update_attributes(cpl_status: "Closed", updated_by: current_user)
    end
    @file = @cpl.file
    @buttons = ['close']
  end

  def tax_proration_calculator
    @buttons = ['save', 'close']
    @ss = SettlementStatement.find params[:id]
  end

  def hoa_proration_calculator
    @buttons = ['save', 'close']
    @ss = SettlementStatement.find params[:id]
  end

  def show_overlay
    if params[:id] != nil && params[:id]  != ""
      @file = Index.find params[:id]
    end

    if params[:company] != nil && params[:company] != ""
      @company = params[:company]
    end

    @overlay = params[:overlay]
    @search_value  = params[:search_value]

    case @overlay

    when "File Entities"
      if params.has_key?(:form)
        @form = params[:form]
      end
      @check = CheckWorking.find params[:check_id] if params.has_key?(:check_id)
      @doc_id = params[:doc_id] if params.has_key?(:doc_id)
      @section = params[:section] if params.has_key?(:section)

      if @search_value != nil && @search_value != ""
        search = @search_value.gsub(" ", "%").gsub("*", "%")
        conditions = "(FirstName LIKE '%#{search}%' OR LastName LIKE '%#{search}%')"

        if search.split("%").size == 2
          search = search.split("%")
          conditions += " OR (FirstName LIKE '%#{search[0]}%' AND LastName LIKE '%#{search[1]}%') OR (FirstName LIKE '%#{search[1]}%' AND LastName LIKE '%#{search[0]}%')"
        end

        @contacts = Entity.where("#{conditions} AND FullName IS NOT NULL AND FullName != ''").order("FullName ASC").limit("100")
      else
        @contacts = []
      end

    when "File Employees"
      @buttons = ['close']
      @employees = Employee.where("IsActive = 'True' AND ID NOT IN (190, 119, 95, 157, 327)")

    when "File Attachments"
      @filebin    = FileBin.where("IsFileImage = -1").order("DirName ASC")
      @attachment = FileImage.new

    when "cpl"
      if @file.cpls.empty?
        @cpl = ClosingProtectionLetter.new(file: @file, company_id: @file.Company)
        @cpl.cpl_gather_data(@file)
      else
        @cpl = @file.cpls.last
        @cpl.cpl_update_data(@cpl.file)
      end

    when "cpl_new"
      @cpl = ClosingProtectionLetter.new(file: @file, company_id: @file.Company)
      @cpl.cpl_gather_data(@file)

    when "cpl_show"
      @cpl = ClosingProtectionLetter.find(params[:cpl_id])

    when "cpl_request"
      @cpl = ClosingProtectionLetter.find(params[:cpl_id])
      response = @cpl.submit_cpl_order
      @cpl.parse_order_response(response,current_user)
      @cpl.save_cpl_pdf(response,random_string)
      @deliver_cpl = true

    when "cpl_cancel"
      @cpl = ClosingProtectionLetter.find(params[:cpl_id])
      if @cpl.cpl_sent?
        response = @cpl.cancel_cpl
        @cpl.parse_cancel_response(response,current_user)
      else
        @cpl.update_attributes(cpl_status: "Canceled", updated_by: current_user)
      end

    when "cpl_close"
      @cpl = ClosingProtectionLetter.find(params[:cpl_id])
      if @cpl.cpl_sent?
        response = @cpl.close_cpl
        @cpl.parse_close_response(response,current_user)
      else
        @cpl.update_attributes(cpl_status: "Closed", updated_by: current_user)
      end
    end
  end

  private

  def identifier
    @buttons    = []
    @identifier = random_string(5)
    @identifier = "#{params[:parent]}_#{@identifier}" if params[:parent]
  end
end
