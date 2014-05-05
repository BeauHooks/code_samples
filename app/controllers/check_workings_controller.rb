class CheckWorkingsController < ApplicationController
  include ActionView::Helpers::NumberHelper

  def index
  end

  def show
    @disbursement = CheckWorking.find(params[:id])
    @file = @disbursement.index
  end

  def create
    @file = Index.where("FileID = #{params[:file_id]}").first
    @hud = @file.huds.first

    #Create Minimalist Check For One Click Add
    check                            = CheckWorking.new
    check.file_id                    = @file.FileID
    check.company_id                 = @file.Company
    check.hold_back                  = 0
    check.funds_type                 = "check"

    if !@file.PrintCheckOffice.nil?
      check.print_office_id = @file.PrintCheckOffice
    else
      check.print_office_id = current_user.employee.Office
    end

    check.save
    @check = check
    respond_to do |format|
      format.js { render "check_workings/update_disbursement_results" }
    end
  end

  def calculate_wire
    hud           = Hud.find(params[:hud_id])
    @file         = Index.where("FileID = #{hud.file_id}").first
    @lender_wire   = hud.lender_wire
    @borrower_wire = hud.borrower_wire
  end

  def create_receipt_overlay
    @file = Index.where("FileID" => params[:file_id]).first
    @view = "funding" if params.has_key?(:view) && params[:view] != ""
  end

  def create_receipt
    @file = Index.where("FileID" => params[:file_id]).first

    receipt                = Receipt.new
    receipt.AccountID      = 1
    receipt.FileID         = @file.FileID
    receipt.DisplayFileID  = @file.DisplayFileID
    receipt.EmployeeID     = current_user.employee.Initials
    receipt.EnteredBy      = current_user.employee_id
    receipt.DateReceived   = Time.now
    receipt.ReceiptAmount  = params[:amount]
    receipt.ReceiptNotes   = params[:notes] if params[:notes] != ""
    receipt.Printed        = -1
    receipt.OfficeID       = params[:office]
    receipt.CompanyID      = params[:company]
    receipt.PayingBankName = params[:paying_bank_name] if params[:paying_bank_name] != ""
    receipt.PayForEntity   = params[:received_for]
    receipt.Instrument = params[:instrument] if params[:instrument] != nil && params[:instrument] != ""
    receipt.PaymentMethod  = params[:funds_type] # Anticipated Wire

    if params[:earnest_money] == "yes"
      receipt.EarnestMoney = -1
    end

    if params[:funds_type] == "7"
      receipt.Payer = "#{@file.company.DirName} #{params[:received_from]}"
      receipt.DateOfGoodFunds = Date.today.to_s(:db)
    else
      receipt.Payer = params[:received_from]
    end

    receipt.save
    @receipt = receipt
    render "check_workings/update_receipt_results"
  end

  def destroy_receipt
    @file = Index.find params[:file_id]
    receipt = Receipt.find params[:receipt_id]
    receipt.destroy
    render "check_workings/update_receipt_results"
  end

  def print_receipt
    @receipt = Receipt.find(params[:id])
    @file = Index.where("FileID = #{@receipt.FileID}").first
    @company = @file.company

    respond_to do |format|
      format.js
    end
  end

  def display_receipt
    filename = params[:content]
    path     = File.expand_path(filename, Rails.root + "tmp/receipts/")
    send_file(path, filename: "receipt.pdf", disposition: "inline")
  end

  def get_check_file_number
    value = params[:check_number].to_s.strip
    company = Company.find(params[:company])

    case params[:company].to_i
    when 101
      payee = "South%Ut%Titl%Co%"
    when 102
      payee = "Terra%Titl%Co%"
    when 103
      payee = "South%Ut%Titl%Co%Cedar%"
    when 104
      payee = "Mesq%Titl%Co%"
    when 106
      payee = "South%Ut%Titl%Co%"
    when 116
      payee = "Mesq%Titl%Co% %A%"
    else
      payee = ''
    end
    check = Check.where("CheckNo = #{value} AND ClearedDate IS NULL AND voiddate IS NULL AND Void = 0 AND CompanyID = #{params[:company]} AND PayeeOne LIKE '#{payee}' AND PayeeOne != '' AND PayeeOne NOT LIKE '%Premium%' AND FundsType = 'Check'").first #rescue nil

    if check != nil
      render js: "$('#create_receipt #received_from').val('#{check.DisplayFileID}'); $('#create_receipt #amount').val('#{number_to_currency(check.Amount, unit: '')}'); $('#create_receipt #notes').val('Transfer from File ##{check.DisplayFileID}.');"
    else
      render js: "addToQueue('error_getting_check', 'application/flash_notice?title=Error Processing Request&notice=Check number #{params[:check_number]} not found for #{company.CompanyName}. Please try again.');"
    end
  end

  def add_payee
    disbursement = CheckWorking.find params[:id]
    @file = Index.where("FileID = #{disbursement.file_id}").first

    if params[:entity_id] == ""
      disbursement.payee_1_id = nil
    else
      entity = Entity.find params[:entity_id]
      disbursement.payee_1_id = params[:entity_id]
      disbursement.payee_1 = entity.name
    end

    disbursement.rules_checked = 0
    disbursement.save
    disbursement.set_preferred_payment()

    disbursement.hud_line_payments.each do |payment|
      payment.entity_id = params[:entity_id]
      payment.save

      line = payment.hud_line
      line.payee_id = payment.entity_id
      line.save
    end

    if params[:entity_id] != "" && @file.file_entities.where("EntityID = #{params[:entity_id]}").first.blank?
      file_entity = FileEntity.new
      file_entity.FileID = @file.FileID
      file_entity.DisplayFileID = @file.DisplayFileID
      file_entity.Position = 34 #'Disbursement Entity'
      file_entity.EntityID = params[:entity_id]
      file_entity.save
    end

    if disbursement.payee_1_id != nil
      @check = disbursement
      @refresh = true
      respond_to do |format|
        format.js { render "hud_lines/update_manage_disbursement" }
      end
    else
      respond_to do |format|
        format.js { render "check_workings/add_payee" }
      end
    end
  end

  def remove_payee
    disbursement = CheckWorking.find params[:id]
    entity_id = disbursement.payee_1_id
    disbursement.payee_1_id = nil
    disbursement.save
    @file = Index.where("FileID = #{disbursement.file_id}").first

    if entity_id != nil && entity_id != ""
      #Delete the FileEntity record if it is only a 'Disbursement Entity' and isn't related to any other checks
      disbursement_entity = @file.file_entities.where("EntityID = #{entity_id} AND Position = 34").first
      if disbursement_entity != nil && CheckWorking.where("payee_1_id = #{entity_id}").size == 0
        disbursement_entity.destroy
      end
    end

    @check = disbursement
    @refresh = true
    respond_to do |format|
      format.js { render "hud_lines/update_manage_disbursement" }
    end
  end

  def show_type
    @type = params[:type]
  end

  def change_purpose
    @purpose = params[:purpose]
  end

  def new
    @file = Index.where("FileID = #{params[:file_id]}").first
  end

  def view_check
    @check = CheckWorking.find params[:id]
    @file = Index.where("FileID = #{params[:file_id]}").first
    @hud = @file.huds.first

    respond_to do |format|
      format.js { render "hud_lines/view_check" }
    end
  end

  def get_printed_confirmation
    @working = CheckWorking.find(params[:id])
    @file = Index.where("FileID = #{@working.file_id}").first

    respond_to do |format|
      format.js
    end
  end

  def display_confirmation
    filename = params[:content]
    path     = File.expand_path(filename, Rails.root + "tmp/confirmation_images/")
    send_file(path, filename: "confirmation.pdf", disposition: "inline")
  end

  def update
    @disbursement = CheckWorking.find params[:id]
    @disbursement.update_attributes(params[:check_working])
    @file = @disbursement.index

    @refresh = (params[:check_working].include?("address_id") || params[:check_working].include?("funds_type") || params[:check_working].include?("payee_1_id") || params[:check_working].include?("purpose"))
    set_refresh_payment(@disbursement)
    unless @refresh
      @errors = CheckWorking.find(@disbursement.id).get_disbursement_errors
      @update_fields = []
      @update_fields << "memo_1" if params[:check_working].include?("purpose") || params[:check_working].include?("purpose_value")
    end
  end

  def update_file
  	@file = Index.where("FileID = #{params[:id]}").first

  	case params[:field]
  	when "HasWireBeforeRecording"
  		if @file.HasWireBeforeRecording == 0 || @file.HasWireBeforeRecording == nil
  			@file.HasWireBeforeRecording = 1
  		else
  			@file.HasWireBeforeRecording = 0
  		end
  	else
  		@file.send(params[:field] + '=', params[:value])
  	end
  	@file.save

  	render nothing: true
  end

  def update_summary
    @file = Index.where("FileID = #{params[:file_id]}").first
    @check = CheckWorking.find(params[:check_id]) if params.has_key?(:check_id)
  end

  def destroy
    check = CheckWorking.find params[:id]
    set_refresh_payment(check)

    if params[:confirm].blank?
      render js: "$.get('#{confirm_destroy_check_working_overlay_path(check)}');"
      return
    end

    file_id = check.file_id
    check.destroy

    @file = Index.where("FileID = #{file_id}").first
    respond_to do |format|
      format.js { render "check_workings/update" }
    end
  end

  def split
    payment = HudLinePayment.find params[:payment_id]
    old_disbursement = CheckWorking.find payment.check_id

    @check = create_disbursement(old_disbursement)
    payment.check_id = @check.id
    payment.save

    @check.amount = payment.amount
    @check.save

    remaining = HudLinePayment.where("check_id = #{old_disbursement.id}")
    if remaining.size == 0
      old_disbursement.destroy
    else
      old_disbursement.amount = remaining.sum("amount").to_f
      old_disbursement.save
    end

    @file = Index.where("FileID = #{@check.file_id}").first
    @refresh = true
    respond_to do |format|
      format.js { render "hud_lines/update_manage_disbursement" }
    end
  end

  def show_merge
    @file = Index.where("FileID = #{params[:file_id]}").first
    respond_to do |format|
      format.js
    end
  end

  def merge
    disbursement = CheckWorking.find(params[:primary_disbursement])
    disbursement.amount = CheckWorking.where("id in (#{disbursement.id}, #{params[:to_merge].join(", ")})").sum("amount")
    disbursement.save

    PaymentDisbursement.where("check_working_id in (#{params[:to_merge].join(", ")})").each do |payment_disbursement|
      payment_disbursement.check_working_id = disbursement.id
      payment_disbursement.payee_name = disbursement.payee_1
      payment_disbursement.save
    end

    params[:to_merge].each do |check_id|
      CheckWorking.find(check_id).destroy
    end

    @file = Index.find params[:file_id]
    @disbursement = CheckWorking.find disbursement.id
    @refresh = true
    set_refresh_payment(@disbursement)
    respond_to do |format|
      format.js { render "check_workings/update" }
    end
  end

  def associate_with_hud_line
    check = CheckWorking.find params[:id]
    @file = Index.where("FileID = #{check.file_id}").first
    @hud = @file.huds.first
    results = @file.huds.last.hud_lines.where("number = #{params[:line]}").limit(1)
    line = results.first

    if line != nil
      list = ""
      amount = results.sum{|l| l.amount.to_f + l.borrower_amount.to_f + l.seller_amount.to_f + l.charges.to_f - l.credits.to_f}
      if amount == 0
        list += "&list[]=Line does not have an amount."
      end

      if list != ""
        render js: "addToQueue('flash_notice_associate_with_hud_line', 'application/flash_notice?confirm=Okay&notice=The following error(s) occured while trying to associate line ' + encodeURIComponent('##{line.number}') + ' with this disbursement.#{list}'); $('input#associate_with_line').focus();"
        return
      end

      line.hud_line_payments.each do |payment|
        disbursement = CheckWorking.find(payment.check_id) rescue nil
        if disbursement == nil
          #do nothing
        elsif disbursement.hud_line_payments.size == 1
          disbursement.destroy
        else
          disbursement.amount = disbursement.hud_line_payments.sum("amount") - payment.amount
        end
        payment.destroy
      end

      line.name.to_s.strip[-3..-1] != " to" ? memo = line.name : memo = line.name.to_s.strip[0...-3]
      number = line.number
      if number == 303 || number == 3097
        amount = amount * -1
        memo = "Buyers Proceeds"
      elsif number == 603 || number == 4097
        memo = "Sellers Proceeds"
      elsif number == 5097 || @file.TransactionDescription1 == "Refinance"
        memo = "Borrower Proceeds"
      end

      payee_name = line.payee_name.blank? ? "BLANK" : line.payee_name

      check.payee_1 = payee_name
      check.amount = amount
      check.memo_1 = memo
      check.updated_at = Time.now.to_s(:db)

      if check.payee_1_id == nil && line.payee_id != nil
        check.payee_1_id = line.payee_id
        check.set_preferred_payment()
      else
        check.save
      end

      payment = HudLinePayment.new
      payment.hud_id = @hud.id
      payment.hud_line_id = line.id
      payment.check_id = check.id
      payment.company_id = @file.Company
      payment.memo_1 = memo
      payment.amount = amount
      payment.created_at = Time.now.to_s(:db)
      payment.updated_at = Time.now.to_s(:db)
      payment.entity_id = check.payee_1_id
      payment.save

      @check = CheckWorking.find(check.id)

      if line.payee_name.blank?
        line.payee_name = "BLANK"
        line.save
      end

      @refresh = true
      respond_to do |format|
        format.js { render "hud_lines/update_manage_disbursement" }
      end
    else
      render js: "addToQueue('flash_notice_associate_with_hud_line', 'application/flash_notice?confirm=Okay&notice=Line number does not point to a valid line. Please try again.');"
    end
  end

  private

  def create_disbursement(disbursement = "new")
    if disbursement == "new"
      new_disbursement                            = CheckWorking.new
      # new_disbursement.file_id                    = @file.FileID
      new_disbursement.company_id                 = @file.Company
      new_disbursement.hold_back                  = 0
      new_disbursement.funds_type                 = "check"
    else
      new_disbursement  = CheckWorking.new
      no_touch = ["id"]
      disbursement.attributes.each do |key, value|
        unless no_touch.include?(key)
          new_disbursement.send(key + "=", value )
        end
      end
    end
    new_disbursement.save
    return new_disbursement
  end

  def set_refresh_payment(disbursement)
    @refresh_payment_lines = [] if @refresh_payment_lines.blank?
    disbursement.payment_disbursements.each do |payment_disbursement|
      @refresh_payment_lines << payment_disbursement.line
    end
  end
end
