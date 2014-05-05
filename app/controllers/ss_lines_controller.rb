class SsLinesController < ApplicationController
  def change_line_type
    line = SsLine.find params[:id]
    line.update_attributes(params[:ss_line])
    line.update_type

    @section = line.ss_section
    @ss = SettlementStatement.find line.ss_section.settlement_statement.id
    respond_to do |format|
      format.js {render "settlement_statements/update_form"}
    end
  end

  def insert_line
    pivot_line = SsLine.find params[:id]
    line_order = pivot_line.ss_section.line_order.split(",")
    hash_order = Hash[line_order.map.with_index.to_a]
    user_id = current_user.employee_id
    line = pivot_line.dup
    line.update_attributes(line_type: params[:ss_line][:line_type], created_by: user_id, updated_by: user_id)

    params[:where] == "above" ? line_order.insert(hash_order["#{pivot_line.id}"], line.id) : line_order.insert(hash_order["#{pivot_line.id}"]+1, line.id)
    line.update_type

    @section = line.ss_section
    @section.line_order = line_order.join(",")
    @section.save
    @ss = SettlementStatement.find line.ss_section.settlement_statement.id
    respond_to do |format|
      format.js {render "settlement_statements/update_form"}
    end
  end

  def destroy
    line = SsLine.find params[:id]
    line_order = line.ss_section.line_order.split(",")
    line_order.delete("#{line.id}")
    line.ss_section.line_order = line_order.join(",")
    line.destroy

    @section = line.ss_section
    @ss = SettlementStatement.find line.ss_section.settlement_statement.id
    respond_to do |format|
      format.js {render "settlement_statements/update_form"}
    end
  end

  def view_payments
    @line = SsLine.find params[:id]
    @file = @line.ss_section.settlement_statement.index
    @view = params[:view]

    respond_to do |format|
      format.js {render "payment_disbursements/index"}
    end
  end
end