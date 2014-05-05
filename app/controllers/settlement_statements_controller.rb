class SettlementStatementsController < ApplicationController

  def index
    @ss = SettlementStatement.all
  end

  def new
    @ss = SettlementStatement.new
  end

  def show
    @ss = SettlementStatement.find(params[:id])
  end

  def update
    ss_json = params[:settlement_statement].gsub("\"ordered_sections\":", "\"ss_sections_attributes\":")
    ss_json = ss_json.gsub("\"ordered_lines\":", "\"ss_lines_attributes\":")
    ss_json = ss_json.gsub("\"ordered_cells\":", "\"ss_line_cells_attributes\":")
    ss = SettlementStatement.update(params[:id], JSON.parse(ss_json))
    if ss.errors.empty?
      has_payment = false
      balanced = true

      ss_line = SsLine.find params[:ss_line_id]
      if ss_line
        has_payment = ss_line.payment_amount != 0
        balanced = (ss_line.payment_amount - ss_line.payment_disbursements.sum("amount") == 0) || (ss_line.payment_amount == 0 && ss_line.payment_disbursements.size == 0)
      end

      render json: {message: "Saved Successfully!", has_payment: has_payment, balanced: balanced}, status: :ok, notice: "this is a message"
    else
      render json: {message: ss.errors.as_json(full_messages: true)}, status: :unprocessable_entity
    end
  end

  def create

  end

  def destroy
    @ss = SettlementStatement.find(params[:id])
  end

  def update_tax_proration
    proration_date = params[:proration_date].split("/")
    month          = proration_date[0]
    day            = proration_date[1]
    year           = proration_date[2]
    db_date        = "#{year}-#{month}-#{day}"

    @ss                    = SettlementStatement.find params[:id]
    @ss.tax_proration_date = db_date
    @ss.tax_total          = params[:total]
    @ss.tax_status         = params[:status]
    @ss.save
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

    @ss              = SettlementStatement.find params[:id]
    @ss.hoa_due      = params[:hoa_due]
    @ss.hoa_start_at = start_db_date
    @ss.hoa_end_at   = end_db_date
    @ss.hoa_amount   = params[:total]
    @ss.hoa_applies  = params[:hoa_applies]
    @ss.save
    @new_record = @ss.update_hoa_proration_lines
    # TODO: change this so that it appends new lines instead of having to refresh the entire form
    respond_to do |format|
      format.js {render "settlement_statements/update_form"}
    end
  end
end