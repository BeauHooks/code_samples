class HudLinesController < ApplicationController
  include ActionView::Helpers::NumberHelper
  before_filter :get_hud
  #respond_to :json

  def index
    @hud_lines = @hud.hud_lines.all
    respond_with @hud_lines
  end

  def show
    @file      = Index.find params[:file_id]
    @line      = HudLine.find(params[:id])
    if params[:type] != "ss_commission_group"
      @line.type = params[:type]
      @line.save
    end
  end

  def new
    @section = params[:section]
    @type    = params[:type]

    respond_to do |format|
      format.js { render "hud_lines/new"}
    end
  end

  def change_purpose
    @line = HudLine.find params[:id]
    @purpose = params[:purpose]
  end

  def view_check
    @line    = HudLine.find params[:id]
    @payment = HudLinePayment.find params[:payment_id]
    @check   = @payment.check_working


    respond_to do |format|
      format.js { render "hud_lines/view_check" }
    end
  end

  def update_check
    @line = HudLine.find params[:id]
    @check = CheckWorking.find params[:check_id]

    @check.send(params[:field] + "=", params[:value])
    @check.updated_at = Time.now.to_s(:db)
    @check.save

    if params[:field] == "funds_type"
      if params[:value] == "check"
        @check.beneficiary_name = nil
        @check.beneficiary_account_number = nil
        @check.beneficiary_bank_name = nil
        @check.beneficiary_bank_routing = nil
      else
        @check.check_deliver = nil
        @check.print_office_id = nil
      end

      @check.save
      @refresh = true

      respond_to do |format|
        format.js { render "hud_lines/update_manage_disbursement" }
      end
    else
      render nothing: true
    end
  end

  def view_payments
    @line = HudLine.find params[:id]
    @file = @line.hud.index
    @view = params[:view]

    respond_to do |format|
      format.js {render "payment_disbursements/index"}
    end
  end

  # CREATE PAYMENT FROM LINE MANAGEMENT SCREEN PLUS SIGN
  def create_payment
    @line = HudLine.find params[:id]

    # Most of this is commented out while we finalize payment creation view
    # This is minimalist version to create payment without any information
    payment            = @line.hud_line_payments.build

    if @line.payee_name != "" && @line.payee_name != nil
      check_working = CheckWorking.where(:file_id => Hud.find(@line.hud_id).file_number, :payee_1 => @line.payee_name)
      # check_working = CheckWorking.where(:file_id => Hud.find(@line.hud_id).file_number, :payee_1_id => params[:entity_id])
    else
      check_working = []
    end

    if check_working.count == 1
      check = check_working.first
      check.amount += params[:amount].to_f
      check.save
    else
      @file = Index.where("FileID = #{@hud.doc.file_id}").first
      check                            = CheckWorking.new
      check.file_id                    = @file.FileID
      if !@file.PrintCheckOffice.nil?
        check.print_office_id = @file.PrintCheckOffice
      else
        check.print_office_id = current_user.employee.Office
      end
      check.company_id                 = @file.Company
      check.payee_1                    = params[:payee_1]
      check.hold_back                  = 0
      check.funds_type                 = "check"
      check.save
    end

    payment.check_id = check.id
    payment.save
  end

  def update_payment
    payment = HudLinePayment.find params[:payment_id]
    payment.send(params[:key] + "=", params[:value])
    payment.save

    check = CheckWorking.find payment.check_id rescue nil
    total = 0.0

    if check
      total = check.hud_line_payments.sum("amount").to_f
      check.amount = total
      check.save
    end

    if params[:type] == "hud_line" || params[:type] == nil
      if params[:current]
        current = params[:current]
      else
        current = params[:id]
      end
      render js: "
        $('#row_#{payment.id}').removeClass('active_row');
        $('#row_#{payment.id}').click();
        $('#row_#{payment.id} input[name=amount]').val('#{number_to_currency(total, unit: '')}');
        updateWallet(#{current}, #{params[:hud_id]});"
    else
      @check = check
      respond_to do |format|
        format.js { render "check_workings/update_payment" }
      end
    end
  end

  def refresh_payments
    @line = HudLine.find params[:id]
  end

  def remove_payment
    @line   = HudLine.find params[:line_id]
    payment = HudLinePayment.find params[:payment_id]
    check   = CheckWorking.find payment.check_id rescue nil
    amount = payment.amount
    payment.delete

    if check != nil && check.hud_line_payments.count > 1
      check.amount -= amount
      check.save
    elsif check != nil
      check.delete
    end

    respond_to do |format|
      format.js { render "hud_lines/remove_payment" }
    end
  end

  def add_payee
    @line  = HudLine.find params[:id]
    entity = Entity.find params[:entity_id]
    render js: "$('#payment_to_company').attr('checked', false);
      $('#payment_to_company').val('false');
      $('#new_payment input[name=entity]').val('#{entity.name}');
      $('#new_payment input[name=payee_1]').val('#{entity.name}');
      $('#new_payment input[name=entity_id]').val('#{entity.EntityID}');
      $('.purpose_fields').hide();
      $('#purpose_results').html('');
      $('.payee_fields').show();"
  end

  def manage
    @line = HudLine.find params[:id]
    @file = @line.hud.doc.index

    respond_to do |format|
      format.js { render "hud_lines/manage"}
    end
  end

  def create
    @section = params[:section]

    if params[:id] != "" && params[:id] != nil
      if params[:line_action] == "insert_above"
        @update_lines = HudLine.where("hud_id = #{params[:hud_id]} AND number >= #{params[:line_num][0]}000 AND number <= #{params[:line_num][0]}095").order("number ASC")
        HudLine.where("hud_id = #{params[:hud_id]} AND number >= #{params[:line_num]} AND number <= #{params[:line_num][0]}095").update_all("number=number+1")
        @line_action     = params[:line_action]
        @line            = HudLine.new
        @line.hud_id     = @hud.id
        @line.number     = params[:line_num]
        @line.created_at = Time.now.to_s(:db)
        @line.created_by = current_user.employee_id
        @line.type       = "#{params[:type]}_custom"
        @line.group      = params[:type] == "ss_commission" || params[:type] == "ss_commission_total" ? "ss_commission" : ""
        @line.updated_at = Time.now.to_s(:db)
        @line.updated_by = current_user.employee_id
        @line.save
      elsif params[:line_action] == "insert_below"
        @update_lines = HudLine.where("hud_id = #{params[:hud_id]} AND number >= #{params[:line_num][0]}000 AND number <= #{params[:line_num][0]}095").order("number ASC")
        HudLine.where("hud_id = #{params[:hud_id]} AND number >= #{params[:line_num]} AND number <= #{params[:line_num][0]}095").update_all("number=number+1")
        @line_action     = params[:line_action]
        @line            = HudLine.new
        @line.hud_id     = @hud.id
        @line.number     = params[:line_num]
        @line.created_at = Time.now.to_s(:db)
        @line.created_by = current_user.employee_id
        @line.type       = "#{params[:type]}_custom"
        @line.group      = params[:type] == "ss_commission" || params[:type] == "ss_commission_total" ? "ss_commission" : ""
        @line.updated_at = Time.now.to_s(:db)
        @line.updated_by = current_user.employee_id
        @line.save
      else
        @action     = "replace"
        @line       = HudLine.find params[:id]
        @line.type  = "#{params[:type]}_custom"
        @line.group = ""
        skip        = false
        @ss_group   = false

        if params[:type].start_with?("ss_")
          @line.type = params[:type] + "_custom"
          if params[:type].start_with?("ss_proration")
            if @hud.hud_lines.where(:number => params[:line_num].to_i + 1).first.name == nil
              @line.type       = "ss_proration_date_custom"
              @line.group      = "ss_proration"
              @line.number     = params[:line_num].to_i
              @line.updated_at = Time.now.to_s(:db)
              @line.updated_by = current_user.employee_id
              @line.save

              @line            = @hud.hud_lines.where(:number => params[:line_num].to_i + 1).first
              @line.type       = "ss_proration_custom"
              @line.group      = "ss_proration"
              @line.updated_at = Time.now.to_s(:db)
              @line.updated_by = current_user.employee_id
              @line.save
            else
              render js: "alert('This line type requires 2 rows!');"
              skip = true
            end
          end
          if params[:type].start_with?("ss_commission")
            @line.group      = "ss_commission"
            @line.updated_at = Time.now.to_s(:db)
            @line.updated_by = current_user.employee_id
            if params[:type] == "ss_commission_group"
              if @hud.hud_lines.where(:number => [params[:line_num].to_i + 1,params[:line_num].to_i + 2,params[:line_num].to_i + 3]).first.name == nil
                @line.type       = "ss_header_custom"
                @line.name       = "COMMISSIONS:"
                @line.amount     = @hud.hud_lines.where("number = 4000").first.credits
                @line.updated_at = Time.now.to_s(:db)
                @line.updated_by = current_user.employee_id
                @line.save

                @line            = @hud.hud_lines.where(:number => params[:line_num].to_i + 1).first
                @line.type       = "ss_commission_custom"
                @line.group      = "ss_commission"
                @line.updated_at = Time.now.to_s(:db)
                @line.updated_by = current_user.employee_id
                @line.save

                @line            = @hud.hud_lines.where(:number => params[:line_num].to_i + 2).first
                @line.type       = "ss_commission_custom"
                @line.group      = "ss_commission"
                @line.updated_at = Time.now.to_s(:db)
                @line.updated_by = current_user.employee_id
                @line.save

                @line            = @hud.hud_lines.where(:number => params[:line_num].to_i + 3).first
                @line.type       = "ss_commission_total_custom"
                @line.group      = "ss_commission"
                @line.updated_at = Time.now.to_s(:db)
                @line.updated_by = current_user.employee_id
                @line.save

                @ss_group        = true
              else
                render js: "alert('This line type requires 4 rows!');"
                skip = true
              end
            end
          end
        end
        if skip != true
          @line.updated_at = Time.now.to_s(:db)
          @line.updated_by = current_user.employee_id
          @line.save
        end
      end
    else
      @action          = "add"
      @line            = HudLine.new
      @line.hud_id     = @hud.id
      @line.number     = @hud.hud_lines.where("number > #{@section} AND number < #{@section.to_i + 20}").last.number + 1
      @line.created_at = Time.now.to_s(:db)
      @line.created_by = current_user.employee_id
      @line.type       = "#{params[:type]}_custom"
      @line.updated_at = Time.now.to_s(:db)
      @line.updated_by = current_user.employee_id

      if @line.number > 800 && @line.number < 900
        @line.description = "(from GFE #3)"

        @gfe_line = HudLine.new
        @gfe_line.hud_id = @hud.id
        @gfe_line.number     = @hud.hud_lines.where("number > 2100 AND number < 2200").order("number ASC").last.number + 1
        @gfe_line.created_at = Time.now.to_s(:db)
        @gfe_line.created_by = current_user.employee_id
        @gfe_line.type       = "m_normal_custom"
        @gfe_line.updated_at = Time.now.to_s(:db)
        @gfe_line.updated_by = current_user.employee_id
        @gfe_line.description = @line.number.to_s
        @gfe_line.save
      end

      @line.save
    end
  end

  def new_description
    @line  = @hud.hud_lines.where("number = #{params[:line]}").first
    @group = params[:group]
    @line_action = params[:line_action]
    @side = params[:side]

    respond_to do |format|
      format.js { render "hud_lines/new"}
    end
  end

  def update
    @hud_line = @hud.hud_lines.find(params[:id])
    if params[:field] == nil || @hud_line.hud.index.SentForFunding != nil
      @refresh = "refresh"
      render "hud_lines/update_view"
      return
    elsif params.has_key?("refresh")
      @refresh = "refresh"
    end

    @field    = params[:field]
    @hud_line.updated_at = Time.now.to_s(:db)
    @hud_line.updated_by = current_user.employee_id
    @update_extra_line_numbers = []

    case params[:field]
    when "start_date"
      split_date = params[:value].split("/")
      value = "#{split_date[2]}-#{split_date[0]}-#{split_date[1]}"
    when "end_date"
      split_date = params[:value].split("/")
      value = "#{split_date[2]}-#{split_date[0]}-#{split_date[1]}"
    else
      params[:value] != "" ? value = params[:value] : value = nil
    end

    if params[:field] == "payee_name"
      if params[:payee_id] == ""
        @hud_line.payee_id = nil
      else
        @hud_line.payee_id = params[:payee_id]
      end
    end

    if params.has_key?("group")
      if params[:group].end_with?("custom")
        if @hud_line.type == ("ss_proration")
          if params[:field] == "charges"
            line = @hud.hud_lines.where(:number => @hud_line.number - 1).first
            line.name = "custom"
            line.save
          end
        else
          group = @hud_line.group
          if group == nil || group == ""
            @hud_line.group = "custom"
          elsif group != "custom"
            @hud_line.group = "#{group}_custom"
          end
        end
      elsif params[:group] == "nil"
        if @hud_line.number == 1400
          @hud_line.group = nil
          @hud_line.save
          if params[:field] == "borrower_amount"
            value = @hud.hud_lines.send("line_#{@hud_line.number}_borrower")
          else
            value = @hud.hud_lines.send("line_#{@hud_line.number}_seller")
          end
        elsif @hud_line.type == "ss_proration"
          line = @hud.hud_lines.where(:number => @hud_line.number - 1).first
          line.name = nil
          line.save
        else
          group = @hud_line.group
          if group == "custom"
            @hud_line.group = nil
            value = @hud.hud_lines.send("line_#{@hud_line.number}") rescue params[:value]
          elsif group.to_s.start_with?("line_1103")
            @hud_line.group = group.gsub("_custom","")
            value = @hud.hud_lines.send("line_1103")
          end
        end
      end
    end

    if params[:field] == "description" && 3000 > @hud_line.number && @hud_line.number > 1400
      line = @hud.hud_lines.where("number = #{value}").first rescue nil
      if line != nil
        @hud_line.name = line.name
        @hud_line.hud_amount = line.amount.to_f + line.borrower_amount.to_f + line.seller_amount.to_f
      else
        @hud_line.name = nil
        @hud_line.hud_amount = nil
      end
    end

    if @hud_line.number == 800 && params[:field] == "amount"
      @hud_line.percent = 0
      # @hud_line.percent = @hud.initial_loan_amount.to_f > 0 ? (value.to_f * 100 / @hud.initial_loan_amount.to_f).to_f : 0
    elsif @hud_line.number == 800 && params[:field] == "percent"
      @hud_line.amount = value.to_f > 0 ? (@hud.initial_loan_amount.to_f * value.to_f/100).to_f : 0
    end

    @hud_line.send("#{params[:field]}" + "=", value)
    @hud_line.save

    case @hud_line.number
    when 107
      file = Index.where("FileID = #{@hud.doc.file_id}").first
      fields = file.file_doc_fields.where("tag LIKE '1099_BUYERS_PART%' AND doc_id = 0 AND is_active = 1 ")
      @hud_line = HudLine.find @hud_line.id
      fields.each do |field|
        field.value = number_to_currency(@hud_line.borrower_amount || 0.0, unit: "")
        field.save
      end
    when 211
      file = Index.where("FileID = #{@hud.doc.file_id}").first
      fields = file.file_doc_fields.where("tag LIKE '1099_BUYERS_PART%' AND doc_id = 0 AND is_active = 1 ")
      @hud_line = HudLine.find @hud_line.id
      fields.each do |field|
        field.value = number_to_currency(@hud_line.borrower_amount || 0.0, unit: "")
        field.save
      end
    when 301..302
      @hud_line = @hud.hud_lines.where(:number => 303).first
      @hud_line.borrower_amount = @hud.hud_lines.line_303
      @hud_line.save
    when 601..602
      @hud_line = @hud.hud_lines.where(:number => 603).first
      @hud_line.seller_amount = @hud.hud_lines.line_603
      @hud_line.save
    when 704
      scan = true
      i = 506

      if @hud_line.poc.to_s != "" && @hud_line.amount.to_f > 0
        while scan
          line = @hud.hud_lines.where("number = #{i}").first
          if line.name.to_s.include?("Earnest Money") || line.name.to_s == ""
            line.name = "Earnest Money"
            line.payee_name = @hud_line.payee_name
            line.payee_id = @hud_line.payee_id
            line.seller_amount = @hud_line.amount
            line.type = "jk_disbursement"
            line.save
            @seller_earnest_money = line
            scan = false
          end

          i += 1
          if i > 519
            scan = false
          end
        end
      else
        while scan
          line = @hud.hud_lines.where("number = #{i}").first
          if line.name.to_s.include?("Earnest Money") || line.name.to_s == ""
            line.name = nil
            line.payee_name = nil
            line.payee_id = nil
            line.seller_amount = nil
            line.save
            @seller_earnest_money = line
            scan = false
          end

          i += 1
          if i > 519
            scan = false
          end
        end
      end

      if params[:field] == "amount"
        line = @hud.hud_lines.where("number = 201").first
        line.borrower_amount = @hud_line.amount
        line.save
      end
    when 804..899
      gfe_lines = @hud.hud_lines.where("number >= 2000 AND number < 3000 AND description = '#{@hud_line.number}'")
      if gfe_lines.size == 0 && @hud_line.description.to_s == "(from GFE #3)"
        @gfe_line = HudLine.new
        @gfe_line.hud_id = @hud.id
        @gfe_line.name = @hud_line.name
        @gfe_line.hud_amount = @hud_line.borrower_amount
        @gfe_line.number     = @hud.hud_lines.where("number > 2100 AND number < 2200").order("number ASC").last.number + 1
        @gfe_line.created_at = Time.now.to_s(:db)
        @gfe_line.created_by = current_user.employee_id
        @gfe_line.type       = "m_normal_custom"
        @gfe_line.updated_at = Time.now.to_s(:db)
        @gfe_line.updated_by = current_user.employee_id
        @gfe_line.description = @hud_line.number.to_s
        @gfe_line.save
      elsif gfe_lines.size > 0 && @hud_line.description.to_s == "(from GFE #1)"
        gfe_lines.each do |gfe_line|
          if gfe_line.type == "m_normal_custom"
            gfe_line.destroy
          else
            gfe_line.name = nil
            gfe_line.hud_amount = nil
            gfe_line.description = nil
            gfe_line.daily_interest = nil
            gfe_line.type = "m_normal_custom"
            gfe_line.updated_at = Time.now.to_s(:db)
            gfe_line.updated_by = current_user.employee_id
            gfe_line.save
          end
          @update_extra_line_numbers << gfe_line.number
        end
      end
    when 1100..1199
      # line = @hud.hud_lines.where("number = 1101").first
      # line.borrower_amount = @hud.hud_lines.where("number > 1101 AND 1200 > number AND number NOT IN (1105, 1106) AND (poc = '' OR poc IS NULL) AND payee_id = #{@hud.hud_lines.where('number = 1102').first.payee_id}").sum("amount").to_f
      # line.save
      if @hud_line.number == 1105
        line = @hud.hud_lines.where("number = 202").first
        line.borrower_amount = @hud_line.amount
        line.save
      end
      if @hud_line.number == 1106
        line = @hud.hud_lines.where("number = 101").first
        line.borrower_amount = @hud_line.amount
        line.save
      end
    # when 3001
    #   line = @hud.hud_lines.where("number = 4001").first
    #   case params[:field]
    #   when "credits"
    #     line.charges = value
    #   when "charges"
    #     line.credits = value
    #   when "amount"
    #     line.amount = value
    #   end
    #   line.save
    when 3013
      file = Index.where("FileID = #{@hud.doc.file_id}").first
      fields = file.file_doc_fields.where("tag LIKE '1099_BUYERS_PART%' AND doc_id = 0 AND is_active = 1 ")
      fields.each do |field|
        field.value = number_to_currency(@hud_line.charges || 0.0, unit: "")
        field.save
      end
    # when 4001
    #   line = @hud.hud_lines.where("number = 3001").first
    #   case params[:field]
    #   when "credits"
    #     line.charges = value
    #   when "charges"
    #     line.credits = value
    #   when "amount"
    #     line.credits = value
    #   end
    #   line.save
    when 2000..2001
      line = @hud.hud_lines.where("number = 2002").first

      if @hud_line.number == 2000
        other_line = @hud.hud_lines.where("number = 2001").first
        line.gfe_amount = @hud_line.gfe_amount.to_f + other_line.gfe_amount.to_f
      else
        other_line = @hud.hud_lines.where("number = 2000").first
        line.gfe_amount = other_line.gfe_amount.to_f + @hud_line.gfe_amount.to_f
      end

      line.save
    end

    if [107, 407, 211, 511, 901].include?(@hud_line.number)
      @tax_lines = ["107", "407", "211", "511"]
      if ["start_date", "end_date"].include?(params[:field]) && (@hud.tax_status == "credit" && [107, 407].include?(@hud_line.number) || @hud.tax_status == "debit" && [107, 511].include?(@hud_line.number) || @hud.tax_status == "none" && [211, 511].include?(@hud_line.number) || (@hud_line.number == 901 && params[:field] == "start_date") )
      # if (params[:field] == "start_date" && [407, 107, 901].include?(@hud_line.number)) || (params[:field] == "end_date" && [511, 211].include?(@hud_line.number))
        [407, 107, 901].include?(@hud_line.number) ? @hud.tax_proration_date = @hud_line.start_date : @hud.tax_proration_date = @hud_line.end_date
        @hud.save
      elsif params.has_key?(:group) && params[:group] != "nil"
        @hud_line.group = "custom"
        @hud_line.save
      elsif params.has_key?(:group) && params[:group] == "nil"
        @hud_line.save
      end
      get_hud
      @hud.update_tax_proration_lines
    end

    if [4012, 4013, 3012, 3013].include?(@hud_line.number)
      @tax_lines = ["4012", "4013", "3012", "3013"]

      if ["start_date", "end_date", "periodic_amount"].include?(params[:field])
        case params[:field]
        when "start_date"
          @hud.tax_proration_date = @hud_line.start_date
        when "end_date"
          @hud.tax_proration_date = @hud_line.end_date
        when "periodic_amount"
          @hud.tax_total = @hud_line.periodic_amount
        end
        @hud.save
      elsif [4013, 3013].include?(@hud_line.number) && params.has_key?(:group) && params[:group] != "nil"
        line = @hud.hud_lines.where("number = #{@hud_line.number - 1}").first
        line.name = "custom"
        line.save
      elsif [4013, 3013].include?(@hud_line.number) && params.has_key?(:group) && params[:group] == "nil"
        line = @hud.hud_lines.where("number = #{@hud_line.number - 1}").first
        line.name = nil
        line.save
      end

      get_hud
      @hud.update_tax_proration_lines
    end

    @hud.updated_at = Time.now.to_s(:db)
    @hud.save

    if (@hud_line.invoice_category != nil || @hud_line.number == 1202 || @hud_line.number == 1101)
      get_hud
      @hud.update_hud_invoice
    end
    render "hud_lines/update_view"
  end

  def update_wallet
    @line = HudLine.find params[:id]

    if params[:borrower_amount] != nil
      @line.borrower_amount = params[:borrower_amount]
      @line.seller_amount   = params[:seller_amount]
      @line.save
    elsif params[:charges] != nil
      @line.charges = params[:charges]
      @line.credits = params[:credits]
      @line.save
    end
  end

  def split
    @line = HudLine.find params[:id]
  end

  def clear
    line = HudLine.find params[:id]
    line.updated_by = current_user.employee_id
    line.updated_at = Time.now.to_s(:db)

    no_touch = ["id", "hud_id", "number", "type", "group", "created_by", "created_at", "updated_at", "updated_by"]

    cannot_change = [100,101,102,103,106,107,108,120,
     200,201,202,203,210,211,212,220,
     300,301,302,303,
     400,401,402,406,407,408,420,
     500,501,502,503,504,505,510,511,512,520,
     600,601,602,603,
     700,703,
     800,801,802,803,804,805,806,807,
     900,901,902,903,
     1000,1001,1002,1003,1004,1007,
     1100,1101,1102,1103,1104,1105,1106,1107,1108,
     1200,1201,1203,1204,1205,
     1300,1301,
     1400,
     2000,2001,2002,2003,
     2100,2101,2102,2103,2104,2105,2106,2107,
     2200,2201,2202,
     3000,3001,3003,3004,3005,3006,3007,3008,3009,3011,3013,3014,3015,3017,3018,3096,3097,3099,
     4000,4001,4003,4004,4005,4006,4007,4008,4009,4011,4013,4014,4015,4017,4018,4096,4097,4099,
     5000,5001,5003,5004,5005,5006,5007,5008,5009,5011,5013,5014,5016,5017,5018,5019,5020,5096,5097,5099]

    if cannot_change.include?(line.number)
      no_touch << "name"
    end

    line.attributes.each do |key, value|
      unless no_touch.include?(key) || value == nil
        line.send(key + "=", nil)
      end
    end

    line.save
    @hud_line = line
    get_hud
    @refresh = "refresh"
    render "hud_lines/update_view"
  end

  def destroy
    @line        = HudLine.find params[:id]
    @line_number = @line.number
    @line_type   = @line.type

    if @line_type.start_with?('ss_')
      if @line_type.start_with?('ss_proration')
        @line = @hud.hud_lines.where(:number => @line.number + 1).first
        @line.name            = nil
        @line.type            = "ss_normal"
        @line.group           = nil
        @line.amount          = nil
        @line.charges         = nil
        @line.credits         = nil
        @line.periodic_amount = nil
        @line.periods         = nil
        @line.description     = nil
        @line.start_date      = nil
        @line.end_date        = nil
        @line.save
      else
        @line.name            = nil
        @line.amount          = nil
        @line.charges         = nil
        @line.credits         = nil
        @line.periodic_amount = nil
        @line.periods         = nil
        @line.payee_name      = nil
        @line.description     = nil
        @line.start_date      = nil
        @line.end_date        = nil
        @line.split           = nil
        @line.save
        @line.destroy
        @update_lines = HudLine.where("hud_id = #{@line.hud_id} AND number >= #{@line.number.to_s[0]}000 AND number <= #{@line.number.to_s[0]}095").order("number ASC")
        HudLine.where("hud_id = #{@line.hud_id} AND number >= #{@line.number} AND number <= #{@line.number.to_s[0]}095").update_all("number=number-1")
      end
    else
      @rows = []
      @gfes = []

      if(@line.number <= 112 || (@line.number >= 120 && @line.number <= 412) || (@line.number >= 420 && @line.number <= 704)  || (@line.number >= 720 && @line.number <= 808)  || (@line.number >= 820 && @line.number <= 904)  || (@line.number >= 1120 && @line.number <= 1206)  || (@line.number >= 1220 && @line.number <= 1305))
        no_touch = ["id", "hud_id", "number", "group", "created_by", "created_at", "updated_at", "updated_by"]
        @line.attributes.each do |key, value|
          unless no_touch.include?(key) || value == nil
            @line.send(key + "=", nil)
          end
        end

        if @line.number < 700
          @line.type = "jk_normal"
        elsif @line.number < 1400
          @line.type = "l_disbursement"
        else
          @line.type = "m_normal"
        end

        @line.updated_by = current_user.employee_id
        @line.updated_at = Time.now.to_s(:db)
        @line.save
        @hide = false
      else
        @hide = true

        gfe_line = @hud.hud_lines.where("number > 2100 AND number < 2200 AND description = '#{@line.number}'").first
        if gfe_line != nil
          @gfe_remove = gfe_line.number
          gfe_line.destroy
          gfe_line.save
        end

        no_touch = ["id", "hud_id", "number", "group", "created_by", "created_at", "updated_at", "updated_by"]
        @line.attributes.each do |key, value|
          unless no_touch.include?(key) || value == nil
            @line.send(key + "=", nil)
          end
        end

        @line.save
        @line.destroy

        @hud.hud_lines.where("number > #{@line_number} AND number < #{@line_number + 20}").order("number ASC").each do |line|
          unless [120, 220, 420, 520].include? line.number
            @rows << line.number

            gfe_line = @hud.hud_lines.where("number > 2100 AND number < 2200 AND description = '#{line.number}'").first
            if gfe_line != nil
              @gfes << gfe_line.number
              gfe_line.number = line.number - 1
              gfe_line.save
            end

            line.number = line.number - 1
            line.save
          end
        end
      end
    end

    if @line.hud_line_payments.count > 0
      @line.hud_line_payments.each do |payment|
        check_id = payment.check_id
        payment.destroy

        check = CheckWorking.find check_id rescue nil
        if check != nil && check.hud_line_payments.count == 0
          check.destroy
        else
          check.amount = check.hud_line_payments.sum("amount").to_f
          check.save
        end
      end
    end

    render "hud_lines/destroy"
    # if @line.number >= 3000
    #   @line.group = nil
    #   @line.save
    # end
  end

  def default
    @rows = []
    @gfes = []

    @line = HudLine.find params[:id]
    @line.revert_to_default
    @line_type = @line.type
    @line_number = @line.number

    render "hud_lines/destroy"
  end

  protected

  def get_hud
    @hud = Hud.find_by_id(params[:hud_id])
    #redirect_to root_path unless @hud
  end
end
