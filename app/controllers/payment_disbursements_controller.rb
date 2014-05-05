class PaymentDisbursementsController < ApplicationController
  def create
    @view = params[:view]

    if params[:hud_line_id].blank?
      line = SsLine.find params[:ss_line_id]
      @file = line.ss_section.settlement_statement.index
    else
      line = HudLine.find params[:hud_line_id]
      @file = line.hud.index
    end

    disbursement = CheckWorking.find(params[:id]) unless params[:id] == "new"
    payment_disbursement = PaymentDisbursement.new(ss_line_id: params[:ss_line_id], hud_line_id: params[:hud_line_id], check_working_id: disbursement.blank? ? nil : disbursement.id, payee_name: disbursement.blank? ? line.get("payee_name") : disbursement.payee_1, amount: line.payment_disbursements.size == 0 ? line.payment_amount : nil, funds_type: disbursement.blank? ? "check" : disbursement.funds_type)
    set_override(payment_disbursement, "create_new") if params[:id] == "new"
    payment_disbursement.save

    @line = params[:hud_line_id].blank? ? SsLine.find(params[:ss_line_id]) : HudLine.find(params[:hud_line_id])
    @refresh_disbursement = true
    respond_to do |format|
      format.js {render "payment_disbursements/index"}
    end
  end

  def update
    @view = params[:view]
    payment_disbursement = PaymentDisbursement.find params[:id]

    if params[:override].blank? && !payment_disbursement.check_working.blank? && !params[:payment_disbursement].include?("amount") && payment_disbursement.check_working.payment_disbursements.size > 1
      render js: "$.get('#{confirm_payment_change_overlay_path(payment_disbursement, payment_disbursement: params[:payment_disbursement], view: params[:view])}');" and return
    end

    set_override(payment_disbursement, params[:override])
    payment_disbursement.update_attributes(params[:payment_disbursement])
    unset_override(payment_disbursement)

    @line = payment_disbursement.line
    @file = payment_disbursement.index

    if params[:override] == "update_all" || params[:payment_disbursement].include?("funds_type") || (params[:payment_disbursement].include?("amount") && @view == "overlay")
      @balance_only = (params[:payment_disbursement].include?("amount") && @view == "overlay")
      @refresh_disbursement = true
      respond_to do |format|
        format.js {render "payment_disbursements/index"}
      end
    end
  end

  def destroy
    @view = params[:view]
    payment_disbursement = PaymentDisbursement.find(params[:id]).destroy
    line = payment_disbursement.line
    file = payment_disbursement.index
    payment_disbursement.destroy

    @line = line.class.table_name == "ss_lines" ? SsLine.find(line.id) : HudLine.find(line.id)
    @file = Index.find(file.ID)
    @refresh_disbursement = true

    respond_to do |format|
      format.js {render "payment_disbursements/index"}
    end
  end

  def split
    payment_disbursement = PaymentDisbursement.find params[:id]
    current = CheckWorking.find payment_disbursement.check_working_id
    new_record = current.dup
    new_record.save
    payment_disbursement.check_working_id = new_record.id
    payment_disbursement.save

    current.update_amount
    new_record.update_amount

    @disbursement = CheckWorking.find new_record.id
    @file = @disbursement.index
    @refresh = true
    respond_to do |format|
      format.js {render "check_workings/update"}
    end
  end

  private

  def set_override(object, override)
    object.override = override
  end

  def unset_override(object)
    object.override = nil
  end
end