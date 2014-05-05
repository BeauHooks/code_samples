class IndexController < ApplicationController
  include ActionView::Helpers::NumberHelper
  respond_to :html, :json, :js
  before_filter :set_options

  def index
    if params[:file_id]
      file_id = params[:file_id]
      company_id = file_id.to_s[0..2]
      session[:company] = company_id if company_id != "" && company_id != nil && Company.where("CompanyID = #{company_id || 0}").first != nil
    end

    if params.has_key?("file_id") && params[:file_id] != ""
      if file_id.class.to_s == "Array"
        files = []
        params[:file_id].each do |f|
          files << f.to_i
        end
        @search_results = Index.select("tblFileInfo.*, tblCompany.*").where("tblFileInfo.FileID IN (#{files.join(', ')}) AND tblFileInfo.Company = #{session[:company]} #{Index.can_view(current_user, session[:company])}").joins("left outer join tblCompany on tblFileInfo.Company = tblCompany.CompanyID").includes(:buyer_1, :seller_1, :lender, :entities, :file_entities, :file_employees, :file_properties, :file_notes).limit(100)
      else
        @search_file_number = params[:file_id].gsub(session[:company].to_s, "")
        @search_results = Index.select("tblFileInfo.*, tblCompany.*").where("tblFileInfo.FileID = #{params[:file_id]} AND tblFileInfo.Company = #{session[:company]} #{Index.can_view(current_user, session[:company])}").joins("left outer join tblCompany on tblFileInfo.Company = tblCompany.CompanyID").includes(:buyer_1, :seller_1, :lender, :entities, :file_entities, :file_employees, :file_properties, :file_notes).limit(100)
      end
    elsif params[:search]
      @search_results = Index.select("tblFileInfo.*, tblCompany.*").where("tblFileInfo.DisplayFileID = '#{params[:search]}' AND tblFileInfo.Company = #{session[:company]} AND tblFileInfo.IsClosed = 0 #{Index.can_view(current_user, session[:company])}").joins("left outer join tblCompany on tblFileInfo.Company = tblCompany.CompanyID").includes(:buyer_1, :seller_1, :lender, :entities, :file_entities, :file_employees, :file_properties, :file_notes).limit(100)
    else
      @search_results = Index.select("tblFileInfo.*, tblCompany.*").where("tblFileInfo.Company = #{session[:company]} AND tblFileInfo.IsClosed = 0 #{Index.can_view(current_user, session[:company])}").joins("left outer join tblCompany on tblFileInfo.Company = tblCompany.CompanyID").includes(:buyer_1, :seller_1, :lender, :entities, :file_entities, :file_employees, :file_properties, :file_notes).limit(100)
    end
    @file = @search_results.empty? ? "No File" : @search_results.first.DisplayFileID
  end

  def show
    @file = Index.includes(:file_properties, :file_notes, :entities).includes(file_entities: [{entity: :entity_contacts}], file_employees: :employee).find(params[:id])
    @employees = Employee.closers(session[:company], @permission_lock_files)
    @file_user_types = FileUserType.all
    if @permission_lock_files
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Opened Order')")
    else
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Searcher', 'Opened Order')")
    end
    @images = @file.file_images.where("Inactive = 0 AND IsPrivate = 0").order("ImageDate DESC")
    @emails = @file.file_emails

    # TODO: Temp code to convert to ID based relations for tblFileInfo
    @file.old_file_employees.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
      end
    end

    @file.old_file_entities.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
      end
    end

    @file.old_file_properties.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
      end
    end

    @file.old_file_notes.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
        @file = Index.includes(:file_properties, :file_notes, :entities).includes(file_entities: [{entity: :entity_contacts}], file_employees: :employee).find(params[:id])
      end
    end
    ##
  end

  def edit
    @file = Index.find(params[:id])
  end

  def create
    @file = Index.new(Index.new.dup.attributes.merge params.select { |k| Index.new.dup.attributes.keys.include? k })
    send_confirmation_email = {}
    send_confirmation_email_company = {}
    @failures = []
    exceptions = {}

    if params[:company].blank?
      @file.Company = session[:company]
    else
      @file.Company = params[:company]
      session[:company] = company
    end

    @file.OrderTakenBy = current_user.employee_id

    case params[:index][:Side]
    when "Both"
      @file.BuyerSide = -1
      @file.SellerSide = -1
    when "Owner"
      @file.SellerSide = -1
      @file.SplitSide = "Buyer"
    when "Lender"
      @file.BuyerSide = -1
      @file.SplitSide = "Seller"
    end

    @file.AdminViewPassword = generate_password() if @file.confidential?

    @file.new_order_file_entities.each do |file_entity|
      if Rails.env.production? && file_entity[:Confirmation] == "Confirmation"
        send_confirmation_email[file_entity.entity.name] = file_entity
      end
    end

    if !@file.new_order_file_employees.map{|e| e.EmployeeID}.include? current_user.employee_id
      file_employee               = @file.file_employees.new
      file_employee.FileID        = @file.FileID
      file_employee.DisplayFileID = @file.DisplayFileID
      file_employee.Position      = FileEmployeeType.find(9).TypeDescription
      file_employee.EmployeeID    = current_user.employee_id
    end

    @file.new_order_file_notes.each do |note|
      note.EnteredBy = current_user.employee_id
    end

    @file.new_order_file_properties.each_with_index do |property, index|
      file_property.ParcelNum = index + 1
    end

    if Rails.env.production?
      if @file.confidential?
        @file.new_order_file_employees.each do |file_employee|
          employee = file_employee.employee
          send_confirmation_email_company[employee.FullName] = employee.Email
        end
      else
        if !@file.company.WebNewOrderEmail.empty?
          send_confirmation_email_company["Search Desk"] = @file.company.WebNewOrderEmail
        end

        @file.new_order_file_employees.each do |e|
          if e.Position.include? "Closer"
            employee = e.employee
            send_confirmation_email_company[employee.FullName] = employee.Email
          end
        end
      end
    end

    if send_confirmation_email_company[current_user.name] == nil
      send_confirmation_email_company[current_user.name] = current_user.email
    end

    # Send confirmation to customers
    send_confirmation_email.each do |name, file_entity|
      begin
        FeedbackMailer.file_confirmation_email(current_user, @file.FileID, name, file_entity.entity.Email).deliver!
        file_entity.sent_confirmation = 1
        file_entity.save
      rescue => ex
        if file_entity != nil && file_entity.entity != nil
          email = file_entity.entity.Email
        else
          email = "NO ENTITY EMAIL FOUND"
        end
        @failures << "#{name}: #{email}"
        exceptions["#{name}: #{email}"] = [ex.message, ex.backtrace]
      end
    end

    # Send confirmation internally
    send_confirmation_email_company.each do |name, email|
      begin
        FeedbackMailer.file_confirmation_email_company(current_user, @file.FileID, name, email).deliver!
      rescue => ex
        @failures << "#{name}: #{email}"
        exceptions["#{name}: #{email}"] = [ex.message, ex.backtrace]
      end
    end

    # Send failures to FTWeb Feedback
    if exceptions.size > 0
      FeedbackMailer.file_confirmation_fail_email(current_user,exceptions).deliver
    end

    @commit = params[:commit]

    if @file.save!
      respond_to do |format|
        format.js { render '/index/js/new_order_confirmation' }
      end
    else
      render js: "$('#saving_new_order').hide(); addToQueue('save_error_new_order', 'application/flash_notice?notice=Something went wrong with your order. If you continue to receive this error message, please contact tech support.');"
    end
  end

  def resend_confirmation
    @file = Index.find params[:id]
    @failures = []
    post_success = ""
    exceptions = Hash.new

    if params.has_key?(:print_copy)
      print_action = "addToQueue('print_confirmation', 'index/#{@file.ID}/print_confirmation#{'?hide_notes=true' if params.has_key?(:hide_notes)}');"
    else
      print_action = ""
    end

    unless !params.has_key?(:entity)
      post_success = "addToQueue('confirmation_success', 'application/flash_notice?title=Confirmation Send Success&notice=Success! Your confirmation was sent.&type=confirmation');"
      if Rails.env.production?
        # Send confirmation to customers
        params[:entity].each do |entity|
          name = Entity.find(entity["entity_id"]).name
          begin
            FeedbackMailer.file_confirmation_email(current_user, @file.FileID, name, entity["email"], params.has_key?(:hide_notes)).deliver!
          rescue => ex
            @failures << "#{name}: #{entity['email']}".gsub("'", "\\\\\'")
            exceptions["#{name}: #{entity['email']}"] = [ex.message, ex.backtrace]
          end
        end
      else
        # Test in staging or development
        name = current_user.employee.FullName
        email = current_user.employee.Email

        params[:entity].each do |entity|
          if entity.has_key?("entity_id")
            name = Entity.find(entity["entity_id"]).name
            @failures << "#{name}: #{entity['email']}"
          end
        end

        begin
          FeedbackMailer.file_confirmation_email(current_user, @file.FileID, name, email, params.has_key?(:hide_notes)).deliver!
        rescue => ex
          @failures << "#{name}: #{email}"
          exceptions["#{name}: #{email}"] = [ex.message, ex.backtrace]
        end
      end
    end

    if @failures.size > 0
      # Send failures to FTWeb Feedback
      FeedbackMailer.file_confirmation_fail_email(current_user,exceptions).deliver if Rails.env.production?
      render js: "closeOverlay('resend_confirmation'); addToQueue('confirmation_failure', 'application/flash_notice?title=Confirmation Send Failure&notice=Confirmation could not be sent to the following:&list[]=#{@failures.join("&list[]=")}'); #{print_action}"
    else
      render js: "closeOverlay('resend_confirmation'); #{post_success} #{print_action}"
    end
  end

  def print_confirmation
    begin
      @file = Index.find params[:id]
      @user = current_user
      @company = @file.company
      @notes = @file.file_notes.where("IsPrivate = 0") if !params.has_key?(:hide_notes)
      @delivery_method = "print"

      case @file.Company.to_i
      when 101
        @logo = "sutc_logo_color.jpg"
      when 102
        @logo = "terra_logo_color.jpg"
      else
        @logo = ""
      end

      @county_properties = []
      @county_images = []

      @file.file_properties.where("Inactive = 0").each do |p|
        unless p.TaxID == nil
          property = Taxroll1.where("serialnum = '#{p.TaxID.gsub("'", "\\\\'").upcase}'").first
          if property != nil
            @county_properties << property

            image = TaxrollImages.where("AccountNum = '#{property.accountnum}'").first
            if image != nil && Rails.env != "staging"
              path = DriveMap.posix(image.BaseDir + image.FileName)
              @county_images << path
            else
              @county_images << nil
            end
          end
        end
      end

      respond_to do |format|
        format.js { render '/index/js/print_confirmation' }
      end
    rescue => ex
      render js: "addToQueue('confirmation_failure', 'application/flash_notice?title=Confirmation Send Failure&notice=#{ex.message}"
    end
  end

  def display_confirmation
    send_file("tmp/confirmation_images/" + params[:content], filename: "confirmation.pdf", disposition: "inline")
  end

  def print_disbursement_sheet
    @file = Index.find params[:id]

    respond_to do |format|
      format.js { render 'index/js/print_disbursement_sheet'}
    end
  end

  def display_disbursement_sheet
    filename = params[:content]
    path     = File.expand_path(filename, Rails.root + "tmp/check_workings/")
    send_file(path, filename: "disbursement.pdf", disposition: "attachment")
  end

  def update
    params[:COEDate] = datetime_parse(params[:COEDate]) if params[:COEDate]
    params[:SalesPrice] = params[:SalesPrice].gsub(",", "").to_d if params[:SalesPrice]
    params[:LoanAmount] = params[:LoanAmount].gsub(",", "").to_d if params[:LoanAmount]
    params[:SecondLoan] = params[:SecondLoan].gsub(",", "").to_d if params[:SecondLoan]

    @file = Index.includes(:file_properties, :file_notes, :entities).includes(file_entities: [{entity: :entity_contacts}], file_employees: :employee).find(params[:id])
    @file.update_attributes(@file.dup.attributes.merge params.select { |k| @file.dup.attributes.keys.include? k })
    @employees = Employee.closers(session[:company], @permission_lock_files)
    @file_user_types = FileUserType.all
    if @permission_lock_files
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Opened Order')")
    else
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Searcher', 'Opened Order')")
    end
    @images = @file.file_images.where("Inactive = 0 AND IsPrivate = 0").order("ImageDate DESC")
    @emails = @file.file_emails

    # TODO: Temp code to convert to ID based relations for tblFileInfo
    @file.old_file_employees.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
      end
    end

    @file.old_file_entities.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
      end
    end

    @file.old_file_properties.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
      end
    end

    @file.old_file_notes.each do |e|
      if e.index_id.nil?
        e.index_id = @file.ID
        e.save!
        @file = Index.includes(:file_properties, :file_notes, :entities).includes(file_entities: [{entity: :entity_contacts}], file_employees: :employee).find(params[:id])
      end
    end
    ##
    render :show
  end

  def cancel_note
    @file = Index.find params[:id]
    @type = "Cancel Note"
    respond_to do |format|
      format.js { render '/index/file_info' }
    end
  end

  def destroy
    @file = Index.find params[:id]

    if @file.is_destroyable?
      @file.destroy
    else
      @file.Bombed = Time.now.to_s(:db)
      @file.IsClosed = -1
      @file.save

      file_note = FileNote.new
      file_note.FileID = @file.FileID
      file_note.DisplayFileID = @file.DisplayFileID
      file_note.NoteDT = Time.now.to_s(:db)
      file_note.EnteredBy = current_user.employee_id
      file_note.NoteText = "CANCELLED: #{params[:message]}"
      file_note.TickleEmployeeID = current_user.employee_id
      file_note.save
      @cancel = true
    end
  end

  def display_search_results
    @search_type = params[:search_type]
    company = !params[:company].blank? ? params[:company].to_i : session[:company]
    query = "tblFileInfo.Company = #{company} #{Index.can_view(current_user, session[:company])} AND "
    query += "tblFileInfo.IsClosed = 0 AND " if !(params.has_key?(:include_closed) || @search_type == "file_number")
    search = params[:search].to_s.gsub("'", "\\\\'").split("*").join("%%")

    if params[:search] == "" && params[:from] == "" && params[:to] == ""
      @search_results = Index.find(:all, conditions: ["tblFileInfo.Company = #{session[:company]} AND tblFileInfo.IsClosed = 0 #{Index.can_view(current_user, session[:company])}"], limit: "50")
      @file = @search_results.first
      return
    end

    case @search_type
    when "file_number"
      # @search_results = Index.file_number_search(search)
      if search.is_numeric?
        count = 0
        file_id = company.to_s + search.to_s
        @record = Index.where(query + "tblFileInfo.FileID = #{file_id}").first
        @search_results = Index.where(query + "tblFileInfo.FileID > #{file_id.to_i - 50} AND tblFileInfo.FileID < #{file_id.to_i + 50}").includes(:buyer_1, :seller_1, :lender, :entities)

        until count == 50 || @record != nil do
          count += 1
          file_id = file_id.to_i - 1
          @record = Index.where(query + "tblFileInfo.FileID = #{file_id}").includes(:buyer_1, :seller_1, :lender, :entities).first
        end
        if count == 50
          @search_results = []
          @record = nil
        else
          @record
        end
      else
        @search_results = []
      end
    when "smart_search"
      @search_results = Index.search params[:search], with: {isclosed: params.has_key?(:include_closed), company: session[:company], admin_view_password: ""}, max_matches: 100, per_page: 100, order: "file_id DESC", sql_order: true
    else
      @search_results = Index.try(@search_type, query, search, to: params[:to], from: params[:from])
    end
    @file = @search_results.first
  end

  def overview
    @file = Index.find params[:id]
    respond_with @file
  end

  def edit_file_info
    @file = Index.find(params[:id])
    @type = params[:type]
  end

  def cancel_update_file_info
    @file = Index.find(params[:id])
    @type = "File Info"
  end

  def file_info
    # Gather Information
    @file = Index.select("tblFileInfo.*, tblCompany.*").where(ID: params[:id]).joins("left outer join tblCompany on tblFileInfo.Company = tblCompany.CompanyID").first
    @file_user_types = FileUserType.find(:all, conditions: ["TypeDescription != 'Disbursement Entity'"], order: ["TypeDescription ASC"])
    if @permission_lock_files
      @employees = Employee.find(:all, :conditions => ["Active != 0 AND ID NOT IN (190, 119, 95, 157, 327)"], :order => "FullName ASC").collect{|e| [e.FullName, e.ID]}
      @file_employee_types = FileEmployeeType.find(:all, :order => "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Opened Order')").collect {|p| [p.TypeDescription, p.ID]}
    else
      @employees = Employee.find(:all, :conditions => ["Active != 0 AND Department = 2 AND ID NOT IN (190, 119, 95, 157, 327) OR ID = 5 "], :order => "FullName ASC").collect{|e| [e.FullName, e.ID]}
      @file_employee_types = FileEmployeeType.find(:all, :order => "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Searcher', 'Opened Order')").collect {|p| [p.TypeDescription, p.ID]}
    end
    @file_notes = @file.file_notes.where("IsPrivate = 0 OR EnteredBy = #{current_user.employee_id} OR TickleEmployeeID = #{current_user.employee_id}")


    case @tab
    when "Attachments"
      # FIXME: Need to make these visible to ADMIN user
      if params[:show_inactive]
        @images = @file.file_images.where("IsPrivate = 0").order("ImageDate DESC")
        @show_inactive = true
      else
        @images = @file.file_images.where('Inactive = 0 AND IsPrivate = 0').order("ImageDate DESC")
        @show_inactive = false
      end
    when "Emails"
      @emails = @file.file_emails
    when "Recording"
      @view = "funding"
    end

    respond_to do |format|
      format.js
    end
  end

  def file_image
    @file     = Index.find params[:id]
    @image_id = params[:image_id]
    path      = DriveMap.posix(@file.file_images.find(@image_id).FullFileName).split("/")
    file      = path.pop
    send_file(path.join("/").downcase + "/" + file)
  end

  def display_all_file_images
    if current_user.employee.ACViewPrivateFile == 0
      render nothing: true
      return
    end

    tmp_path = Rails.root.join("tmp", "#{params[:tmp_file]}")
    send_file(tmp_path, filename: "images.pdf", disposition: "inline")
  end

  def file_email
    @file       = Index.find params[:id]
    @message_id = params[:message_id]
    @email      = Message.find @message_id
    send_file "/mnt/email_archive/#{@email.location}/#{@email.filename}"
  end

  def change_company
    @company = params[:id]
    session[:company] = @company
  end

  def add_contact_to_new_file
    @contact = Entity.find(params[:entity_id])
    @position = params[:position]
  end

  def add_employee_to_new_file
    @employee = Employee.find(params[:employee_id])
    @position = params[:position]
  end

  def update_employee_options
    options = {}
    options[""] = ""
    company_condition = params[:checked] == 'checked' ? "" : "AND Company = #{params[:company]}"

    if @permission_lock_files
      Employee.where("(Active != 0 AND ID NOT IN (190, 119, 95, 157, 327) #{company_condition})").order("FullName ASC").each do |employee|
        options["#{employee.ID}"] = employee.FullName
      end
    else
      Employee.where("(Active != 0 AND Department = 2 AND ID NOT IN (190, 119, 95, 157, 327) #{company_condition}) OR ID = 5").order("FullName ASC").each do |employee|
        options["#{employee.ID}"] = employee.FullName
      end
    end

    js = "$('#new_file_employees').find('select#employee_ID').each(function(){var selected = $(this).val(); $(this).find('option').remove().end()"
    options.each do |id, name|
      js += ".append(\"<option value='#{id}'>#{name.html_safe}</option>\")"
    end
    js += ".val(selected).change();});"

    render js: js
  end

  def add_property_to_new_file
    if params[:file_id] != nil
      @file = Index.find params[:file_id]
    end
    @property = Taxroll1.select("`taxroll1`.*, `taxroll2`.FullLegal").joins(:taxroll2).find(params[:property_id])
  end

  def search_employees(string)
    params[:search] = string
    @employees = Employee.search(params)
  end

  def update_file_stage
    @file = Index.find(params[:id])
    @stage = params[:type]
    error_list = []

    case params[:type]
    when "Date Down"
      @file.DateDownEntered = Time.now.to_s(:db)
      @file.DateDownEnteredBy = current_user.employee_id
      @file.save
    when "Funding"
      total_invoices = 0.0
      total_fees = 0.0
      warnings = []

      # Get errors for individual disbursements
      @file.check_workings.each do |disbursement|
        unless params.has_key?(:skip_warnings)
          disbursement.get_disbursement_warnings.each do |warning|
            warnings << "#{CGI.escape disbursement.payee_1} - #{warning}"
          end
        end

        disbursement.get_disbursement_errors.each do |error|
          disbursement.payee_1.to_s != "" ? error_list << "#{CGI.escape disbursement.payee_1} - #{error}" : error_list << "#{number_to_currency(disbursement.amount, unit: '$')} - #{error}"
        end
      end

      unless params.has_key?(:skip_warnings)
        total_invoices = @file.invoices.where("void = 0").sum{|invoice| invoice.InvoiceTotal.to_f}
        total_fees = @file.check_workings.where("payee_1_id = #{@file.Company} AND purpose != 'FILE'").sum{|disbursement| disbursement.amount.to_f}

        if total_invoices != total_fees
          warnings << "Disbursements to company do not match invoices."
        end

        #Check if file balances
        total = @file.receipts.sum("ReceiptAmount") - @file.check_workings.sum("amount") + @file.adjustments.sum("incrdeccash")
        if total > 0
          warnings << "File does not balance to zero."
        elsif total < 0
          fail_update_stage(@stage, "File disbursements exceed receipts amounts.")
          return
        end

        if warnings.size > 0
          warnings = "&list[]=" + warnings.join("&list[]=")
          render js: "addToQueue('skip_warnings', 'application/flash_notice?title=Warning#{warnings}&notice=The following warnings were raised. Would you like to proceed anyway?&confirm=Continue&type_action=Yes&cancel_action=' + encodeURIComponent('$(\\\'input.send_funding\\\').val(\\\'Send\\\'); $(\\\'input.send_funding\\\').attr(\\\'disabled\\\', false);') + '&click_action=' + encodeURIComponent(\"sendForFunding('skip_warnings');\") );"
          return
        end
      end

      list_1099 = []

      # Force print office where necessary.
      force_print_office()

      #Check that all checks payable to us are accounted for as invoice of file-to-file
      @file = Index.find(@file.ID)
      if @file.check_workings.where("(payee_1 LIKE 'southe%ut%titl%' OR payee_1 LIKE 'terra%titl%' OR payee_1 LIKE 'mesquit%titl%') AND (purpose_value IS NULL OR purpose_value = '') AND (check_id IS NULL OR check_id = '') AND funds_type = 'check' ").size > 0
        error_list << "For all checks payable to the company please indicate a purpose. Either an invoice number, file number or explanation."
      end

      if error_list.size == 0
        unless params.has_key?(:no_disbursements)
          #Check that file is receipting, disbursing, or adjustments. Fail if none.
          if @file.receipts.sum("ReceiptAmount") + @file.check_workings.sum("amount") + @file.adjustments.sum("incrdeccash") == 0
            fail_update_stage(@stage, "There are no moneys in or out of this file. Send for funding cancelled.")
            return
          end
        end

        #Check to ensure that 1099's in file are complete/have tax ids (Or checkbox for "No 1099's" is checked)
        list_1099 = @file.docs.find(:all, conditions: ["doc_templates.short_name = '1099' AND docs.is_active = -1"], include: [:doc_template])
        if list_1099.size == 0 && !params.has_key?(:no_1099s)
          fail_update_stage(@stage, "Either a 1099 must exist or 'No 1099s' must be checked.")
          return
        elsif !params.has_key?(:no_1099s)
          error_list = check_1099s(list_1099, error_list)
        end
      end

      if error_list.size == 0
        unless params.has_key?(:no_disbursements)
          # Create the live checks and then assign their id's to the respective record in check_working
          @file.check_workings.each do |working|
            unless working.check_id != nil
              disbursement = create_live_check(working)
              working.check_id = disbursement.id
              working.save
            end
          end
        end

        list_1099.each do |doc|
          unless doc.filing_1099_id != nil
            create_1099_filing(doc)
          end
        end

        #If they have checked that there are no disbursements, send a notice to all other closers on this file that it does not require funding.
        if params.has_key?(:no_disbursements)
          closer_list = @file.file_employees.where("Position LIKE 'Closer%' AND EmployeeID != #{current_user.employee_id}")
          subject = "File ##{@file.DisplayFileID} does NOT require funding."
          message = "Automatic Message: - File ##{@file.DisplayFileID} has just been sent for funding. You are listed as an employee on this file as well. I have indicated that this file does not require funding. If you believe this is in error please notify me or disbursements immediately."

          if !Rails.env.production?
            closer_list = @file.file_employees.where("EmployeeID = #{current_user.employee_id}")
            subject += "**TESTING**"
            message = "**TESTING**\n" + message + "\n**TESTING**"
          end

          # Send confirmation internally
          closer_list.each do |closer|
            NoticeMailer.send_message(current_user, subject, message, closer.employee.FullName, closer.employee.Email).deliver!
          end
        end

        time = Time.now.to_s(:db)
        unless @file.Recorded != nil
          @file.huds.each do |hud|
            invoice = hud.invoice
            invoice.InvDate = time
            invoice.save
          end
        end

        if params.has_key?(:no_disbursements)
          @file.FundingRequired = 0
          @file.Funded = Time.now.to_s(:db)
          @file.FundedBy = current_user.employee_id
        end

        @file.SentForFunding = time
        @file.save

        # Update Mark and Andy when file is sent for funding from new system
        NoticeMailer.notification(current_user, "File ##{@file.DisplayFileID} Sent for Funding.", "#{current_user.employee.FullName} has sent a file for funding through the new system.", "Mark Meacham", "markm@efusionpro.com").deliver if Rails.env.production?
        NoticeMailer.notification(current_user, "File ##{@file.DisplayFileID} Sent for Funding.", "#{current_user.employee.FullName} has sent a file for funding through the new system.", "Andrew Bryner", "andy@titlemanagers.com").deliver if Rails.env.production?
      end
    end

    if error_list.size == 0
      @type = "update_row"
      @update_stage = true
      respond_to do |format|
        format.js { render '/index/file_info' }
      end
    else
      fail_update_stage(@stage, "Please correct the following errors before continuing:", error_list)
      return
    end
  end

  def unique_tax_id
    render js: get_duplicate_file_from_properties(params[:taxid], params[:accountnum], params[:company])
  end

  def load_tab
    @file = Index.find(params[:id])
    @tab = params[:tab]
  end

  def gather_contacts
    @file = Index.find(params[:id])
    @choices = []
    @file.file_entities.each do |file_entity|
      if file_entity.entity != nil
        name = file_entity.entity.name.gsub(/[']/, "\\\\\\\[']").gsub('[', '').gsub(']', '').gsub('\n', '').gsub('\r', '')
        @choices << name
      end
    end

    company = Company.find @file.Company rescue nil
    if company != nil
      @choices << company.CompanyName
    end

    render text: @choices
  end

  def gather_disbursement_contacts
    file = Index.find(params[:id])
    choices = []
    file.check_workings.each do |disbursement|
      choices << disbursement.payee_1.gsub(/[']/, "\\\\\\\[']").gsub('[', '').gsub(']', '').gsub('\n', '').gsub('\r', '')
    end

    render text: choices.uniq
  end

  def refresh_disbursements
    @file = Index.find params[:id]
  end

  def toggle_balance_view
    @file = Index.find params[:id]
    @view = params[:view]
  end

  private

  def get_duplicate_file_from_properties(tax_id_list, accountnum_list, company)
    taxids = "''"
    accountnums = "''"

    if tax_id_list != nil
      tax_id_list.each do |p|
        unless p == nil
          taxids == "''" ? taxids = "'#{p.gsub("'", "\\\\'")}'" : taxids += ", '#{p.gsub("'", "\\\\'")}'"
        end
      end
    end

    if accountnum_list != nil
      accountnum_list.each do |p|
        unless p == nil
          accountnums == "''" ? accountnums = "'#{p.gsub("'", "\\\\'")}'" : accountnums += ", '#{p.gsub("'", "\\\\'")}'"
        end
      end
    end

    files = Index.find(:all, select: ["tblFileInfo.FileID, tblFileInfo.DisplayFileID, tblFileInfo.Company, tblCompany.DirName, tblFileProperties.TaxID, tblFileProperties.AccountID"], conditions: ["( (tblFileProperties.TaxID in (#{taxids}) AND tblFileProperties.TaxID IS NOT NULL AND tblFileProperties.TaxID != '') OR (tblFileProperties.AccountID in (#{accountnums}) AND tblFileProperties.AccountID IS NOT NULL AND tblFileProperties.AccountID != '') OR (tblFileInfo.TaxID1 in (#{taxids}) AND tblFileInfo.TaxID1 IS NOT NULL AND tblFileInfo.TaxID1 != '' ) ) #{Index.can_view(current_user, session[:company])} AND tblFileInfo.IsClosed = 0 AND tblFileInfo.Opened > '#{Time.now - 2.years}'"], include: [:file_properties, :company], order: ["tblCompany.DirName ASC, tblFileInfo.DisplayFileID DESC"])
    if files.size > 0
      file_list = "$('table#duplicate_property_table').find('tr').each(function(){$(this).remove()}); "
      count = 0
      files.each do |f|
        count += 1
        if f.Company == company.to_i
          link = "<a href='index?file_id=#{f.FileID}' target='_blank'>#{count}) #{f.company.DirName} ##{f.DisplayFileID}. Opened by #{f.order_taken_by != nil ? f.order_taken_by.FullName : 'Employee Not Found'} on #{f.Opened != nil ? f.Opened.strftime("%m/%d/%Y") : 'Error displaying date.'}.</a>"
        else
          link = "#{count}) #{f.company.DirName} ##{f.DisplayFileID}. Opened by #{f.order_taken_by != nil ? f.order_taken_by.FullName : 'Employee Not Found'} on #{f.Opened != nil ? f.Opened.strftime("%m/%d/%Y") : 'Error displaying date.'}."
        end
        file_list += "$('table#duplicate_property_table').append(\"<tr><td>#{link}</td></tr>\");"
      end
      return "$('#property_flash_text').html('One or more properties already have files open on them. PLEASE CLICK ON AND REVIEW THE FILE NUMBER(S) BELOW.'); #{file_list} $('div#property_flash').show();"
    end
    return "$('div#property_flash').hide();"
  end

  def fail_update_stage(stage, message, error_list = [])
    @error_list = error_list
    error_list.size > 0 ? error_list = "&list[]=" + error_list.uniq.join("&list[]=") : error_list = ""
    button = params[:type].split(" ").join("_").downcase
    message = message.gsub("'", "\\\\\'")

    render js: "addToQueue('error_updating_file_stage', 'application/flash_notice?title=Send For #{params[:type]} Error&notice=' + encodeURIComponent('#{message}') + '#{error_list}');
        $('input.send_#{button}').val('Send');
        $('input.send_#{button}').attr('disabled', false);"
  end

  def check_1099s(list_1099, error_list)
    total_gross_proceeds = 0.0
    list_1099.each do |doc|
      check_fields = ["Seller Name", "Forwarding", "City", "State", "Zip", "Tax ID", "Full Property Address", "Gross Proceeds", "Reviewed"]
      check_fields.each do |tag_name|
        case tag_name
        when "Full Property Address"
          tag = "FULL_PROPERTY_ADDRESS"
        when "Reviewed"
          tag = "CB_1099_REVIEWED_#{doc.doc_entity_id}"
        when "Forwarding"
          tag = "GRANTOR_ADDRESS_1"
        when "City"
          tag = "GRANTOR_CITY"
        when "State"
          tag = "GRANTOR_STATE"
        when "Zip"
          tag = "GRANTOR_ZIP"
        else
          tag = "1099_#{tag_name.upcase.split(" ").join("_")}_#{doc.doc_entity_id}"
        end

        field = doc.file_doc_fields.where("tag = '#{tag}' AND is_active != 0").first
        value = nil

        if field != nil
          value = field.value
        else
          field = @file.file_doc_fields.where("tag = '#{tag}'").first
          value = field.value if field != nil
        end

        if tag_name == "Full Property Address" && field != nil && field.value.to_s.length > 39
          error_list << "1099 property description must be 39 characters or less. Current character count is at #{field.value.length}. "
        end

        if tag_name == "Reviewed" && value != "1"
          error_list << "All 1099s must be marked as reviewed."
        end

        if value.to_s == ""
          case tag_name
          when "Seller Name"
            error_list << "Fill out Seller Name on all 1099s."
          when "Forwarding" # Seller's address
            error_list << "Fill out Seller Address on all 1099s."
          when "City"
            error_list << "Fill out Seller City on all 1099s."
          when "State"
            error_list << "Fill out Seller State on all 1099s."
          when "Zip"
            error_list << "Fill out Seller Zip on all 1099s."
          when "Tax ID"
            error_list << "Fill out Tax ID on all 1099s."
          when "Full Property Address"
            error_list << "Fill out Property Description on all 1099s."
          end
        end

        if tag_name == "Gross Proceeds" && value.gsub("$", "").gsub(",", "").to_f > 0
          total_gross_proceeds += value.gsub("$", "").gsub(",", "").to_f
        elsif tag_name == "Gross Proceeds"
          error_list << "Gross Proceeds should be greater than $0.00 on all 1099s."
        end
      end
    end

    if total_gross_proceeds > @file.SalesPrice.to_f
      error_list << "1099 total cannot exceed sales price. Sales Price: #{number_to_currency(@file.SalesPrice.to_f, unit: '$')}. 1099 Total: #{number_to_currency(total_gross_proceeds, unit: '$')}"
    end
  end

  def force_print_office()
    Index.find(@file.ID).check_workings.where("(funds_type = 'wire' OR payee_1 LIKE 'Washington%County%Tr%') AND print_office_id != 21").each do |c|
      c.print_office_id = 21 # Send To Deb
      c.save
    end

    Index.find(@file.ID).check_workings.where("(payee_1 LIKE 'Terra%titl%' OR (payee_1 LIKE 'Mesquit%titl%' AND company_id = 104) OR payee_1 LIKE 'Southern%ut%titl%' OR payee_1 LIKE 'Land%Exchange%') AND print_office_id != 25").each do |c|
      c.print_office_id = 25 # Change to John (Office #25)
      c.save
    end

    Index.find(@file.ID).check_workings.where("payee_1 LIKE 'Southern%ut%titl%Cedar' AND print_office_id != 18").each do |c|
      c.print_office_id = 18 # Cedar does their own
      c.save
    end

    Index.find(@file.ID).check_workings.where("payee_1 LIKE 'Southern%ut%titl%' AND company_id = 106 AND print_office_id != 12").each do |c|
      c.print_office_id = 12 # Kanab does their own
      c.save
    end

    print_office = current_user.employee.Office
    Index.find(@file.ID).check_workings.where("print_office_id IS NULL").each do |c|
      c.print_office_id = print_office
      c.save
    end
  end

  def create_live_check(working)
    disbursement = Check.new
    disbursement.FileID = @file.FileID
    disbursement.DisplayFileID = @file.DisplayFileID
    disbursement.PayeeTwo = working.payee_2
    disbursement.Amount = working.amount
    disbursement.checkdeliver =  working.check_deliver
    disbursement.FundsType = working.funds_type.to_s.titleize
    disbursement.PrintOffice = working.print_office_id
    disbursement.CompanyID = @file.Company
    disbursement.Purpose = working.purpose
    disbursement.PurposeNum = working.purpose_value
    disbursement.PrintPriorToRecording = 0

    # Initialize these or the old disbursement system will dupe checks
    disbursement.CheckPrinted = 0
    disbursement.Void = 0
    disbursement.Cleared = 0
    disbursement.SentForClearing = 0
    disbursement.OKToClear = 0
    disbursement.IsApproved = 0
    disbursement.ServerWireOkToSendDT = nil
    disbursement.CheckNo = nil

    if working.hold_back.to_i == 1
      disbursement.Hold = "H"
      disbursement.HoldBACK = -1
    end

    case disbursement.FundsType
    when "Check"
      if working.payee_1_id == @file.Company
        disbursement.PayeeOne = working.payee_1 + " Insurance Premium Trust"
      else
        disbursement.PayeeOne = working.payee_1
      end
      disbursement.MemoOne =  working.memo_1
      disbursement.Address1 = working.address_1
      disbursement.AddrCity = working.city
      disbursement.AddrState = working.state.to_s
      disbursement.AddrZipCode = working.zip.to_s

      #temporarily set Address 2 to City, State Zip until we've corrected this in the old system.
      disbursement.Address2 =  "#{working.city}#{", #{working.state}" if working.state.to_s != ""}#{" #{working.zip}" if working.zip.to_s != ""}"
    when "Wire"
      disbursement.PayeeOne = working.beneficiary_name
      disbursement.wire_BeneficiaryName = working.beneficiary_name
      disbursement.wire_BeneficiaryAccountNumber = working.beneficiary_account_number
      disbursement.wire_BeneficiaryBankName = working.beneficiary_bank_name
      disbursement.wire_BeneficiaryBankRoutingNum = working.beneficiary_bank_routing
      disbursement.wire_B2BInformationMessage = working.b2b_information_message
    end
    disbursement.save
    disbursement
  end

  def create_1099_filing(doc)
    filing = Filing1099.new
    filing.FileID = @file.FileID
    filing.CaseFileNo2 = @file.DisplayFileID.to_i
    filing.TaxID4 = @file.company.TaxID
    filing.CompanyID = @file.Company
    doc.doc_entity.entity.IndCorp != "Individual" ? filing.IsCompany = -1 : filing.IsCompany = 0

    doc_entity_id = doc.doc_entity_id
    tags = ["1099_SELLER_NAME_#{doc_entity_id}", "GRANTOR_ADDRESS_1", "GRANTOR_ADDRESS_2",
      "GRANTOR_CITY", "GRANTOR_STATE", "GRANTOR_ZIP", "1099_TAX_ID_#{doc_entity_id}",
      "1099_BUYERS_PART_#{doc_entity_id}", "1099_GROSS_PROCEEDS_#{doc_entity_id}", "CB_1099_#{doc_entity_id}", "CB_1099_REVIEWED_#{doc_entity_id}", "GRANTOR_SIGNING_DATE", "FULL_PROPERTY_ADDRESS"]

    tags.each do |tag|
      field = doc.file_doc_fields.where("tag = '#{tag}' AND is_active != 0").first
      field = @file.file_doc_fields.where("tag = '#{tag}' AND doc_id = 0").first if field == nil
      case tag
      when "1099_SELLER_NAME_#{doc_entity_id}"
        filing.SellerName5 = field.value
      when "GRANTOR_ADDRESS_1"
        filing.SellerAddress6 = field.value
      when "GRANTOR_ADDRESS_2"
        filing.SellerAddress6 = "#{filing.SellerAddress6} #{field.value}" if !field.value.blank?
      when "GRANTOR_CITY"
        filing.City7 = field.value
      when "GRANTOR_STATE"
        filing.State8 = field.value
      when "GRANTOR_ZIP"
        filing.Zip9 = field.value
      when "1099_TAX_ID_#{doc_entity_id}"
        filing.SSNTaxID10 = field.value
      when "FULL_PROPERTY_ADDRESS"
        filing.PropertyDescrip11 = field.value
      when "1099_GROSS_PROCEEDS_#{doc_entity_id}"
        filing.GrossProceeds12 = field.value.gsub(",", "").to_i
      when "1099_BUYERS_PART_#{doc_entity_id}"
        field.value == "" ? filing.BuyersPartorREtax15 = "0" : filing.BuyersPartorREtax15 = field.value
      when "CB_1099_#{doc_entity_id}"
        filing.OtherthanCash13 = field.value.to_i * -1
      when "CB_1099_REVIEWED_#{doc_entity_id}"
        filing.IsReviewed = field.value.to_i * -1
        filing.ReviewedDT = field.updated_at
        filing.ReviewedBy = field.updated_by
      when "GRANTOR_SIGNING_DATE"
        filing.ClosingDate14 = datetime_parse(field.value) if field.value.to_s != ""
      end
    end

    doc_signatures = @file.file_doc_entities.where("doc_id = #{doc.id}").order("sort_order ASC")
    if doc_signatures.size == 0
      doc_signatures = @file.file_doc_entities.where("doc_id = 0 AND id = #{doc_entity_id}").order("sort_order ASC")
    end

    doc_signatures.each do |doc_entity|
      unless doc_entity.rolodex_signature_id == nil
        break if filing.Signature2 != nil

        rolodex_signature = RolodexSignature.find(doc_entity.rolodex_signature_id)
        parent = rolodex_signature.rolodex_signature_entities.where("parent_id = 0").first
        unless parent == nil
          if doc_entity.entity.IndCorp != "Individual"
            filing.SigningCompany = parent.name
            RolodexSignatureEntity.where("parent_id = #{parent.id}").each do |child|
              break if filing.Signature2 != nil

              while (child != nil && filing.Signature2 == nil)
                if child.relationship == "signature"
                  if filing.Signature1 == nil
                    filing.Signature1 = child.name
                    break
                  elsif filing.Signature2 == nil
                    filing.Signature2 = child.name
                    break
                  end
                end
                child = RolodexSignatureEntity.where("parent_id = #{child.id}").first
              end
            end
          elsif filing.Signature1 == nil
            filing.Signature1 = parent.name
          elsif filing.Signature2 == nil
            filing.Signature2 = parent.name
            break
          end
        end
      end
    end
    filing.save
    doc.filing_1099_id = filing.id
    doc.save
  end

  def generate_password()
    string   = []
    chars    = 'ABCDEFGHJKLMNOPQRSTUVWXYZ123456789'
    5.times do |i|
      piece = ""
      5.times { |j| piece << chars[rand(chars.length)] }
      string << piece
    end
    return string.join("-")
  end

  def set_options
    @select_options = Entity::SELECT_OPTIONS
    @search_display = Index::SEARCH_DISPLAY
  end
end