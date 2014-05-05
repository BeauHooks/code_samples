class HudsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  respond_to :html, :json

  def export_to_new
    hud = Hud.find(params[:id])
    hud.export(current_user)
    render nothing: true
  end

  def index
    @huds = Hud.all
    respond_with @huds
  end

  def show
    @hud = Hud.find(params[:id])
    respond_to do |format|
      format.html {render layout: 'hud'}
    end
  end

  def toggle_view
    @hud = Hud.find params[:id]
    @view = params[:view]
  end

  def edit
    @hud = Hud.find(params[:id])
  end

  def new
    @hud = Hud.new
  end

  def create
    file = Index.find(params[:id])
    hud = file.hud.new(type: params[:type])
  end

  def update
    hud = Hud.find params[:id]

    if hud.index.SentForFunding != nil
      render js: "$('##{params[:field]}').val('#{hud.send(params[:field].to_sym)}');
      addToQueue('cannot_edit_hud', 'application/flash_notice?notice=File has been sent for funding. Changes can no longer be made to this document.'); "
      return
    end

    value = params[:value]
    hud.send("#{params[:field]}" + '=', value)
    hud.updated_at = Time.now.to_s(:db)
    hud.save

    if params[:field] == "initial_payment_amount"
      payments = hud.hud_lines.where("number >= 1002 AND number <= 1006").sum("periodic_amount").to_f
      initial = hud.initial_payment_amount.to_f
      total = payments + initial
      if payments != hud.escrow_payment_amount
        payments > 0 ? hud.escrow_payment_amount = payments : hud.escrow_payment_amount = nil
      end
      total > 0 ? hud.total_payment_amount = total : hud.total_payment_amount = nil
      hud.save

      render js: "var value = Number('#{total}');
                  if(value > 0 && $('input[name=CB_MONTHLY_ESCROW_1]').attr('checked') != 'checked'){
                    $('input[name=CB_MONTHLY_ESCROW_1]').click();
                  }
                  else if(value == 0 && $('input[name=CB_MONTHLY_ESCROW_2]').attr('checked') != 'checked'){
                    $('input[name=CB_MONTHLY_ESCROW_2]').click();
                  }
                  $('#escrow_payment_amount').val('#{number_to_currency(payments, unit: "") if payments > 0}');
                  $('#total_payment_amount').val('#{number_to_currency(total, unit: "") if total > 0}');"
    elsif params[:field] == "initial_loan_amount"
      @hud_line = hud.hud_lines.where("number = 202").first
      @hud_line.borrower_amount = hud.initial_loan_amount
      @hud_line.save

      @hud = Hud.find hud.id
      render "hud_lines/update_view"
    else
      render nothing: true
    end
    #@hud.update_attributes params[:hud]
  end

  def destroy
  end

  def dashboard
    show
  end

  def hoa_proration_calculator
    @hud = Hud.find params[:id]
  end

  def update_hoa_proration
    hoa_due       = params[:hoa_due]
    start_date    = params[:proration_start].split("/")
    start_month   = start_date[0]
    start_day     = start_date[1]
    start_year    = start_date[2]
    start_db_date = "#{start_year}-#{start_month}-#{start_day}"

    end_date    = params[:proration_end].split("/")
    end_month   = end_date[0]
    end_day     = end_date[1]
    end_year    = end_date[2]
    end_db_date = "#{end_year}-#{end_month}-#{end_day}"

    @hud              = Hud.find params[:id]
    @hud.hoa_due      = params[:hoa_due]
    @hud.hoa_start_at = start_db_date
    @hud.hoa_end_at   = end_db_date
    @hud.hoa_amount   = params[:total]
    @hud.hoa_applies  = params[:hoa_applies]
    @hud.save
    @hud.update_hoa_proration_lines
    respond_to do |format|
      format.js { render 'huds/update_hoa_proration' }
    end
  end

  def tax_proration_calculator
    @hud = Hud.find params[:id]
  end

  def update_tax_proration
    proration_date = params[:proration_date].split("/")
    month          = proration_date[0]
    day            = proration_date[1]
    year           = proration_date[2]
    db_date        = "#{year}-#{month}-#{day}"

    @hud                    = Hud.find params[:id]
    @hud.tax_proration_date = db_date
    @hud.tax_total          = params[:total]
    @hud.tax_status         = params[:status]
    @hud.save

    case @hud.hud_type
    when "standard"
      @tax_lines = ["107", "407", "211", "511"]
    when "in-house"
      @tax_lines = ["4012", "4013", "3012", "3013", "4014", "3014"]
    end
    @hud.update_tax_proration_lines

    respond_to do |format|
      format.js { render 'huds/update_tax_proration' }
    end
  end

  def print
    @hud = Hud.find(params[:id])

    respond_to do |format|
      format.html { render :layout => 'hud' }
      format.pdf {
        html = render_to_string(:layout => 'hud' , :action => "print.haml")
        kit = PDFKit.new(html)
        send_data(kit.to_pdf, :filename => "hud.pdf", :type => 'application/pdf')
        return # to avoid double render call
      }
    end
  end

  def create_hud(doc, type = "standard")
    hud         = Hud.new
    hud.file_id = @file.FileID
    # Create HUD Lines
    hud.setup(type)
    hud.save
    hud.invoice_id = create_invoice_from_hud(hud, type) # Creates a new doc and invoice
    hud.save

    hud.file_number = @file.DisplayFileID
    hud.hud_type = type
    hud.borrower_name     = @file.file_doc_fields.where("tag = 'GRANTEE_NAMES' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_address1 = @file.file_doc_fields.where("tag = 'GRANTEE_ADDRESS_1' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_address2 = @file.file_doc_fields.where("tag = 'GRANTEE_ADDRESS_2' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_city     = @file.file_doc_fields.where("tag = 'GRANTEE_CITY' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_state    = @file.file_doc_fields.where("tag = 'GRANTEE_STATE' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_zip      = @file.file_doc_fields.where("tag = 'GRANTEE_ZIP' AND doc_id = 0 AND is_active = 1").first.value

    if type != "loan-in-house"
      hud.seller_name     = @file.file_doc_fields.where("tag = 'GRANTOR_NAMES' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_address1 = @file.file_doc_fields.where("tag = 'GRANTOR_ADDRESS_1' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_address2 = @file.file_doc_fields.where("tag = 'GRANTOR_ADDRESS_2' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_city     = @file.file_doc_fields.where("tag = 'GRANTOR_CITY' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_state    = @file.file_doc_fields.where("tag = 'GRANTOR_STATE' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_zip      = @file.file_doc_fields.where("tag = 'GRANTOR_ZIP' AND doc_id = 0 AND is_active = 1").first.value
    end

    lender = @file.file_entities.where("Position = 3").last
    if  lender != nil
      lender              = lender.entity
      hud.lender_name     = lender.name
      hud.lender_address1 = "#{lender.address[0]} #{lender.address[1]}"
      # hud.lender_address2 = lender.address[1]
      hud.lender_city     = lender.address[2]
      hud.lender_state    = lender.address[3]
      hud.lender_zip      = lender.address[4]

      list = ["NAME", "ADDRESS_1", "ADDRESS_2", "CITY", "STATE", "ZIP"]

      list.each do |tag|
        field = @file.file_doc_fields.where("doc_id = 0 AND tag = 'LENDER_#{tag}' AND is_active = 1").first
        if field == nil
          field = FileDocField.new
          field.tag = "LENDER_#{tag}"
          field.file_id = @file.FileID
          field.doc_id = 0
          field.is_active = 1
          field.created_by = current_user.employee_id
          field.created_at = Time.now.to_s(:db)
        end

        field.updated_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)

        case tag
        when "NAME"
          field.value = hud.lender_name
        when "ADDRESS_1"
          field.value = lender.address[0]
        when "ADDRESS_2"
          field.value = lender.address[1]
        when "CITY"
          field.value = hud.lender_city
        when "STATE"
          field.value = hud.lender_state
        when "ZIP"
          field.value = hud.lender_zip
        end

        field.save
      end

      # Payee in 800 Section
      fill_lines = [801, 804, 805, 806, 807, 5017, 5018, 5019, 5020]
      fill_lines.each do |l|
        line = hud.hud_lines.where(:number => l).first
        if line
          line.payee_name = lender.name
          line.payee_id   = lender.EntityID
          line.save
        end
      end
    end

    agent    = ""
    location = ""
    @file.file_employees.where("Position like 'Closer%' ").each do |closer|
      if agent == ""
        agent    = "#{closer.employee.FullName}"
        location = "#{closer.employee.closer.office.OfficeAddress1} #{closer.employee.closer.office.OfficeAddress2}, #{closer.employee.closer.office.OfficeCity}, #{closer.employee.closer.office.OfficeState} #{closer.employee.closer.office.OfficeZip}" rescue ""
      else
        agent += " and #{closer.employee.FullName}"
      end
    end
    hud.settlement_agent   = agent if agent != ""
    hud.settlement_date    = @file.COEDate
    hud.settlment_location = location if location != ""
    hud.loan_number        = @file.LoanNum
    schedule_a_old = @file.property_reports.last

    if type == "standard"
      # Set up Totals so we can disburse to Buyer and Seller as neccessary
      sides = {"GRANTOR" => 603, "GRANTEE" => 303}
      sides.each do |key, value|
        entity = @file.file_doc_entities.where("tag = '#{key}'").first
        if entity
          line            = hud.hud_lines.where(:number => value).first
          line.payee_name = @file.file_doc_fields.where("tag = '#{key}_NAMES' AND doc_id = 0 AND is_active != 0").first.value
          line.payee_id   = entity.entity_id
          line.save
        end
      end

      if @file.file_doc_fields.where("tag='COMPANY_PHONE' AND doc_id=0 AND is_active != 0").first == nil
        field = FileDocField.new
        field.doc_id = 0
        field.file_id = @file.FileID
        field.tag = "COMPANY_PHONE"
        field.value = @file.company.CompanyPhone rescue ""
        field.is_active = 1
        field.created_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end

      if @file.file_doc_fields.where("tag='SETTLEMENT_PHONE' AND doc_id=0 AND is_active != 0").first == nil
        field = FileDocField.new
        field.doc_id = 0
        field.file_id = @file.FileID
        field.tag = "SETTLEMENT_PHONE"
        field.value = number_to_phone(@file.closer.office.OfficePhone, area_code: true) rescue ""
        field.is_active = 1
        field.created_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end

      # Import Company for 1100 Section
      company    = Company.find @file.Company
      fill_lines = [1101, 1102, 1103, 1104, 1105, 1106, 1201, 1202]
      fill_lines.each do |l|
        line            = hud.hud_lines.where(:number => l).first
        if ( (l == 1103 && @file.SellerSide == 0) || (l == 1104 && @file.BuyerSide == 0) ) && (@file.SellerSide != 0 || @file.BuyerSide != 0)
          line.payee_name = @file.SplitTitle if @file.SplitTitle != ""
        else
          line.payee_name = company.CompanyName
          line.payee_id   = company.CompanyID
        end

        case l
        when 1102
          line.invoice_category = "ClosingFee"
        when 1103
          line.invoice_category = "OwnerPol"
        when 1104
          line.invoice_category = "LenderPol/Endorsements"
        when 1201
          line.invoice_category = "RecFee"
        when 1202
          line.invoice_category = "RecFee"
        end

        line.save
      end

      # County Information
      case company.DefaultCounty
      when 1
        id = 177906
      when 2
        id = 186270
      when 4
        id = 275601
      when 5
        id = 364122
      end

      if id != nil
        entity = Entity.find id
        fill_lines = [106, 107, 108, 510, 511, 512, 1203, 1204, 1205]
        year = Time.now.strftime("%Y")

        fill_lines.each do |l|
          line            = hud.hud_lines.where(:number => l).first
          line.payee_name = entity.name
          line.payee_id   = entity.EntityID
          line.save
        end
      end

      line = hud.hud_lines.where('number = 901').first
      line.start_date = @file.COEDate
      if line.start_date != nil && line.start_date != ""
        date = line.start_date.to_s.split("-")
        date[1] = (date[1].to_i + 1).to_s
        # If the month spills over 12, reset it to 1 and increment to next year
        if date[1] == "13"
          date[1] = "01"
          date[0] = (date[0].to_i + 1).to_s
        end
        date[2] = "01"
        date = date.join("-")
        line.end_date = date
      end
      line.save
      line = nil

      earnest_money = Receipt.where("FileID = #{@file.FileID} AND EarnestMoney != 0").first
      if earnest_money != nil
        line            = hud.hud_lines.where(:number => 704).first
        line.payee_name = company.CompanyName
        line.payee_id   = company.CompanyID
        line.amount     = earnest_money.ReceiptAmount.to_f
        line.save
      end

      # Realtor Brokerage for commission lines
      realtors = []
      realtors << @file.file_entities.where("Position" => 12).first
      realtors << @file.file_entities.where("Position" => 13).first
      @file.file_entities.where("Position" => 14).each do |brokerage|
        realtors << brokerage
      end
      n = 0
      realtors.each do |r|
        if r != nil
          n += 1
          if n == 1
            line            = hud.hud_lines.where(:number => 701).first
            line.payee_name = r.entity.name
            line.payee_id   = r.EntityID
            line.save

            if r.Position == 12 && earnest_money == nil
              line            = hud.hud_lines.where(:number => 704).first
              line.payee_name = r.entity.name
              line.payee_id   = r.EntityID
              line.save
            end
          elsif n == 2
            line            = hud.hud_lines.where(:number => 702).first
            line.payee_name = r.entity.name
            line.payee_id   = r.EntityID
            line.save
            break
          end
        end
      end

      if schedule_a_old.nil?
        line                 = hud.hud_lines.where(:number => 101).first
        line.borrower_amount = @file.SalesPrice
        line.save

        line                 = hud.hud_lines.where(:number => 202).first
        line.borrower_amount = @file.LoanAmount
        line.save

        hud.initial_loan_amount = @file.LoanAmount

        line               = hud.hud_lines.where(:number => 401).first
        line.seller_amount = @file.SalesPrice
        line.save

        line        = hud.hud_lines.where(:number => 700).first
        line.amount = @file.SalesPrice
        line.save

        settlement_costs   = 295.00
        line               = hud.hud_lines.where(:number => 1102).first
        line.seller_amount = settlement_costs if @file.TransactionDescription1 != "Refinance" && @file.TransactionDescription1 != "Construction Loan"
        line.amount        = settlement_costs
        line.save

        line        = hud.hud_lines.where(:number => 1105).first
        line.amount = @file.LoanAmount
        line.save

        line        = hud.hud_lines.where(:number => 1106).first
        line.amount = @file.SalesPrice
        line.save

        line                    = hud.hud_lines.where(:number => 1104).first
        line.invoice_category   = "Endorsements"
        line.payee_name         = @file.company.CompanyName
        line.save
      else
        line                 = hud.hud_lines.where(:number => 101).first
        line.borrower_amount = schedule_a_old.Policy1Amount || 0
        line.save

        line                 = hud.hud_lines.where(:number => 202).first
        line.borrower_amount = schedule_a_old.Policy2Amount || 0
        line.save

        hud.initial_loan_amount = schedule_a_old.Policy2Amount || 0

        line               = hud.hud_lines.where(:number => 401).first
        line.seller_amount = schedule_a_old.Policy1Amount || 0
        line.save

        line        = hud.hud_lines.where(:number => 700).first
        line.amount = schedule_a_old.Policy1Amount || 0
        line.save

        settlement_costs   = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
        line               = hud.hud_lines.where(:number => 1102).first
        line.seller_amount = settlement_costs if @file.TransactionDescription1 != "Refinance" && @file.TransactionDescription1 != "Construction Loan"
        line.amount        = settlement_costs
        line.save

        line         = hud.hud_lines.where(:number => 1103).first
        line.borrower_amount  =  schedule_a_old.OwnerPremiumAmt
        line.save

        line         = hud.hud_lines.where(:number => 1104).first
        line.amount  =  schedule_a_old.AltaPremiumAmt
        line.save

        # Policy 1 is the Sales Price
        line        = hud.hud_lines.where(:number => 1105).first
        line.amount = schedule_a_old.Policy1Amount.nil? ? 0 : schedule_a_old.Policy1Amount
        line.save

        # Policy 2 is the Loan Amount
        line        = hud.hud_lines.where(:number => 1106).first
        line.amount = schedule_a_old.Policy2Amount.nil? ? 0 : schedule_a_old.Policy2Amount
        line.save

        line                    = hud.hud_lines.where(:number => 1104).first
        line.description        = "#{schedule_a_old.Endorsements}"
        line.endorsement_amount = schedule_a_old.EndorsementAmt
        line.invoice_category   = "Endorsements"
        line.payee_name         = @file.company.CompanyName
        line.save
      end

    elsif type == "in-house"
      line         = hud.hud_lines.where(:number => 3000).first
      line.charges = schedule_a_old.nil? ? @file.SalesPrice : schedule_a_old.Policy1Amount.to_f
      line.save

      line         = hud.hud_lines.where(:number => 4000).first
      line.credits = schedule_a_old.nil? ? @file.SalesPrice : schedule_a_old.Policy1Amount.to_f
      line.save

      closing_date = @file.file_doc_fields.where("tag = 'CLOSING_DATE' and doc_id = 0").first.value

      if closing_date != ""
        month = closing_date.split("/")[0] rescue Time.now.strftime("%m")
        day = closing_date.split("/")[1] rescue Time.now.strftime("%d")
        year = closing_date.split("/")[2] rescue Time.now.strftime("%Y")

        line = hud.hud_lines.where(:number => 4012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = "#{year}-#{month}-#{day} 00:00:00" # @file.Recorded unless @file.Recorded.nil?
        line.save

        line = hud.hud_lines.where(:number => 3012).first
        line.start_date = "#{year}-#{month}-#{day.to_i} 00:00:00" # @file.Recorded + 1.day unless @file.Recorded.nil?
        line.start_date += 1.day rescue nil
        line.end_date   = "#{Time.now.strftime("%Y").to_i + 1}-01-01 00:00:00"
        line.save
      else
        line = hud.hud_lines.where(:number => 4012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = @file.COEDate
        line.save

        line = hud.hud_lines.where(:number => 3012).first
        line.start_date = @file.COEDate # @file.Recorded + 1.day unless @file.Recorded.nil?
        line.start_date += 1.day rescue nil
        line.end_date   = "#{Time.now.strftime("%Y").to_i + 1}-01-01 00:00:00"
        line.save
      end

      # Set up Totals so we can disburse to Buyer and Seller as neccessary
      sides = {"GRANTOR" => 4097, "GRANTEE" => 3097}
      sides.each do |key, value|
        entity = @file.file_doc_entities.where("tag = '#{key}'").first
        if entity
          line            = hud.hud_lines.where(:number => value).first
          line.payee_name = @file.file_doc_fields.where("tag = '#{key}_VESTING' AND doc_id = 0").first.value
          line.payee_id   = entity.entity_id
          line.save
        end
      end

      # Import Company for 1100 Section
      company = Company.find @file.Company
      fill_lines = [3004, 3005, 3006, 3007, 3008, 3009, 4004, 4005, 4006, 4007, 4008, 4009]
      fill_lines.each do |l|
        line = hud.hud_lines.where(:number => l).first
        line.payee_name = company.CompanyName
        line.payee_id = company.CompanyID

        case l
        when 3004
          line.invoice_category = "LenderPol"
          if schedule_a_old.nil? == false
            alta_prem    = schedule_a_old.AltaPremiumAmt || 0
            endorsements = schedule_a_old.EndorsementAmt || 0
            line.charges  =  alta_prem.to_f + endorsements.to_f
          end
        when 3005
          line.invoice_category = "RecFee"
        when 3006
          line.invoice_category = "ClosingFee"
          if schedule_a_old.nil? == false
            settlement_costs = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
            line.charges = settlement_costs
          else
            line.charges = 295.00
          end
        when 3007
          line.invoice_category = "EscrowCol"
        when 3008
          line.invoice_category = "FedEx"
        when 3009
          line.invoice_category = "DocPrep"
        when 4004
          line.invoice_category = "OwnerPol"
          if schedule_a_old.nil? == false
            line.charges = schedule_a_old.OwnerPremiumAmt.nil? ? 0 : schedule_a_old.OwnerPremiumAmt
          end
        when 4005
          line.invoice_category = "RecFee"
        when 4006
          line.invoice_category = "ClosingFee"
          if schedule_a_old.nil? == false
            settlement_costs = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
            line.charges = settlement_costs
          else
            line.charges = 295.00
          end
        when 4007
          line.invoice_category = "EscrowCol"
        when 4008
          line.invoice_category = "FedEx"
        when 4009
          line.invoice_category = "DocPrep"
        end

        line.save
      end

      earnest_money = Receipt.where("FileID = #{@file.FileID} AND EarnestMoney != 0").first
      if earnest_money != nil
        lines = [4001, 3001]
        lines.each do |number|
          line            = hud.hud_lines.where(:number => number).first
          line.payee_name = company.CompanyName
          line.payee_id   = company.CompanyID
          line.amount     = earnest_money.ReceiptAmount
          line.save
        end
      end

      # Realtor Brokerage for commission lines
      realtors = []
      realtors << @file.file_entities.where("Position" => 12).first
      realtors << @file.file_entities.where("Position" => 13).first
      @file.file_entities.where("Position" => 14).each do |brokerage|
        realtors << brokerage if brokerage != nil
      end

      if realtors.count > 0
        line = hud.hud_lines.where(:number => 4020).first
        line.group      = "ss_commission"
        line.type       = "ss_header_custom"
        line.name       = "COMMISSIONS:"
        line.amount     = @file.SalesPrice
        line.save

        line            = hud.hud_lines.where(:number => 4023).first
        line.type       = "ss_commission_total_custom"
        line.group      = "ss_commission"
        line.save
      end

      i = 0
      j = 0
      while i < 2 && j < realtors.count
        if realtors[j] != nil
          line            = hud.hud_lines.where(:number => 4021 + i).first
          line.payee_name = realtors[j].entity.name
          line.payee_id   = realtors[j].EntityID
          line.percent    = 3
          line.type       = "ss_commission_custom"
          line.group      = "ss_commission"
          line.save
          i += 1

          if realtors[j].Position == 12 && earnest_money == nil
            lines = [4001, 3001]
            lines.each do |number|
              line            = hud.hud_lines.where(:number => number).first
              line.payee_name = realtors[j].entity.name
              line.payee_id   = realtors[j].EntityID
              line.save
            end
          end
        end
        j += 1
      end

      while i < 2
        line            = hud.hud_lines.where(:number => 4021 + i).first
        line.type       = "ss_commission_custom"
        line.group      = "ss_commission"
        line.save
        i += 1
      end

      # County Information
      case company.DefaultCounty
      when 1
        id = 177906
      when 2
        id = 186270
      when 4
        id = 275601
      when 5
        id = 364122
      end

      if id != nil
        entity = Entity.find id
        fill_lines = [3013, 4013]
        fill_lines.each do |l|
          line            = hud.hud_lines.where(:number => l).first
          line.payee_name = entity.name
          line.payee_id   = entity.EntityID
          line.save
        end
      end

      # Set up seller finance if needed.
      if @file.TransactionDescription1 = "Seller Finance"
        line = hud.hud_lines.where("number = 3021").first
        line.type = "ss_normal"
        line.name = "Trust Deed and Note with Sellers"
        line.save

        line = hud.hud_lines.where("number = 4025").first
        line.type = "ss_normal"
        line.name = "Trust Deed and Note with Buyers"
        line.save
      end

    elsif type == "loan-in-house"
      line         = hud.hud_lines.where(:number => 5000).first
      line.credits = schedule_a_old.nil? ? @file.LoanAmount : schedule_a_old.Policy2Amount.to_f
      line.save

      # Set up Totals so we can disburse to Buyer as neccessary
      entity = @file.file_doc_entities.where("tag = 'GRANTEE'").first
      if entity
        line            = hud.hud_lines.where(:number => 5099).first
        line.payee_name = @file.file_doc_fields.where("tag = 'GRANTEE_NAMES' AND doc_id = 0").first.value
        line.payee_id   = entity.entity_id
        line.save
      end

      closing_date = @file.file_doc_fields.where("tag = 'CLOSING_DATE' and doc_id = 0").first.value
      if closing_date != ""
        month = closing_date.split("/")[0] rescue Time.now.strftime("%m")
        day = closing_date.split("/")[1] rescue Time.now.strftime("%d")
        year = closing_date.split("/")[2] rescue Time.now.strftime("%Y")

        line = hud.hud_lines.where(:number => 5012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = "#{year}-#{month}-#{day} 00:00:00" # @file.Recorded unless @file.Recorded.nil?
        line.save
      else
        line = hud.hud_lines.where(:number => 5012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = @file.COEDate
        line.save
      end

      # Import Company for 1100 Section
      company = Company.find @file.Company
      fill_lines = [5004, 5005, 5006, 5007, 5008, 5009]
      fill_lines.each do |l|
        line = hud.hud_lines.where(:number => l).first
        line.payee_name = company.CompanyName
        line.payee_id = company.CompanyID

        case l
        when 5004
          line.invoice_category = "LenderPol"
          if schedule_a_old.nil? == false
            alta_prem    = schedule_a_old.AltaPremiumAmt || 0
            endorsements = schedule_a_old.EndorsementAmt || 0
            line.charges  =  alta_prem.to_f + endorsements.to_f
          end
        when 5005
          line.invoice_category = "RecFee"
        when 5006
          line.invoice_category = "ClosingFee"
          if schedule_a_old.nil? == false
            settlement_costs = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
            line.charges = settlement_costs
          else
            line.charges = 295.00
          end
        when 5007
          line.invoice_category = "EscrowCol"
        when 5008
          line.invoice_category = "FedEx"
        when 5009
          line.invoice_category = "DocPrep"
        end

        line.save
      end

      # County Information
      case company.DefaultCounty
      when 1
        id = 177906
      when 2
        id = 186270
      when 4
        id = 275601
      when 5
        id = 364122
      end

      if id != nil
        entity = Entity.find id
        fill_lines = [5013]
        fill_lines.each do |l|
          line            = hud.hud_lines.where(:number => l).first
          line.payee_name = entity.name
          line.payee_id   = entity.EntityID
          line.save
        end
      end
    end

    address                = @file.file_doc_fields.where("tag = 'PROPERTY_ADDRESS' and is_active = 1 and doc_id = 0").first.value
    if address != ""
      address               = "#{address}"
      city                  = ", #{@file.file_doc_fields.where("tag = 'PROPERTY_CITY' and is_active = 1 and doc_id = 0").first.value}" rescue ""
      state                 = ", #{@file.file_doc_fields.where("tag = 'PROPERTY_STATE' and is_active = 1 and doc_id = 0").first.value}" rescue ""
      zip                   = " #{@file.file_doc_fields.where("tag = 'PROPERTY_ZIP' and is_active = 1 and doc_id = 0").first.value}" rescue ""
      hud.property_location = "#{address}#{city}#{state}#{zip}"
    end

    hud.invoice_id = create_invoice_from_hud(hud, type) # Creates a new doc and invoice
    hud.save


    # Update Mark and Andy when file is sent for funding from new system
    case type
    when "standard"
      name = "HUD"
    when "in-house"
      name = "Inhouse Settlement Statement"
    when "loan-in-house"
      name = "Loan Inhouse Settlement Statement"
    end

    NoticeMailer.notification(current_user, "File ##{@file.DisplayFileID} #{name} Created.", "#{current_user.employee.FullName} has created a #{name} through the new system.", "Mark Meacham", "markm@efusionpro.com").deliver if Rails.env.production?
    NoticeMailer.notification(current_user, "File ##{@file.DisplayFileID} #{name} Created.", "#{current_user.employee.FullName} has created a #{name} through the new system.", "Andrew Bryner", "andy@titlemanagers.com").deliver if Rails.env.production?
    return hud
  end

  def create_invoice_from_hud(hud, type)
    time                      = Time.now.to_s(:db)
    template                  = DocTemplate.where(" short_name = 'INV' ").first

    invoice                   = Invoice.new
    invoice.from_ftweb        = -1
    invoice.Fileid            = @file.FileID
    invoice.DisplayFileID     = @file.DisplayFileID
    invoice.DeliverTo         = "Accounting"
    invoice.InvoiceEmployeeID = current_user.employee_id
    invoice.EmployeeInitials  = "#{current_user.first_name[0]}#{current_user.last_name[0]}"
    invoice.CompanyID         = @file.Company
    invoice.EnteredBy         = current_user.employee_id
    invoice.EnteredDT         = Time.now.to_s(:db)
    invoice.EntityID          = 0
    total = 0.0

    # BEGIN TOTAL: Totals up all of the hud lines with invoice categories and stores the amount in the proper field on the invoice
    categories = ["ClosingFee", "Endorsements", "DocPrep", "ExchangeFee", "FedEx", "EscrowCol", "Recon", "RecFee", "LimRpt", "CancelFee", "Forclose", "Lit", "PlatFee", "LenderPol", "OwnerPol", "JuniorPol", "TransferTax", "CPLEndorsement"]
    case type
    when "standard"
      name              = "HUD"
      categories.each do |category|
        amount = hud.hud_lines.where("invoice_category = '#{category}'").sum{|l| (l.amount || 0.0) + (l.borrower_amount || 0.0) + (l.seller_amount || 0.0)}.to_f
        invoice.send(category + "=", amount)
        total += amount
      end
    else
      name              = "Settlement Statement"
      categories.each do |category|
        amount = hud.hud_lines.where("invoice_category = '#{category}'").sum{|l| (l.amount || 0.0) + (l.charges || 0.0) - (l.credits || 0.0)}.to_f
        invoice.send(category + "=", amount)
        total += amount
      end
    end

    invoice.InvoiceTotal = total
    invoice.InvoiceBalance = total
    # END TOTAL

    invoice.Notes = "This invoice was created from #{name} Fees. Changes made here WILL NOT affect the #{name} from which this invoice was generated. Changes made from the #{name} will overwrite changes made here."


    if @file.TransactionDescription1 == ("Refinance" || "Construction Loan")
      invoice.Owner = @file.file_doc_fields.where("doc_id = 0 AND tag = 'GRANTEE_NAMES' ").first.value || nil
    else
      invoice.Owner = @file.file_doc_fields.where("doc_id = 0 AND tag = 'GRANTOR_NAMES' ").first.value || nil
    end

    invoice.PropertyID = @file.file_doc_fields.where("doc_id = 0 AND tag = 'PROPERTY_ADDRESS' ").first.value || nil

    invoice.save

    doc                       = Doc.new
    doc.file_id               = @file.FileID
    doc.company_id            = @file.Company
    doc.doc_template_id       = template.id
    doc.doc_signature_type_id = template.doc_template_versions.where("version = #{template.current_version}").first.doc_signature_type_id
    doc.doc_template_version  = template.current_version
    doc.template_text         = template.doc_template_versions.where("version = #{template.current_version}").first.template_text
    doc.created_by            = current_user.employee_id
    doc.updated_by            = current_user.employee_id
    doc.updated_at            = time
    doc.created_at            = time
    doc.description           = name
    doc.invoice_id            = invoice.id
    doc.save

    return invoice.id
  end
end
