class SsLineCellsController < ApplicationController

  def update_attributes
    user_id = current_user.employee_id
    javascript = ""

    params[:cells].each do |id, transaction|
      cell = SsLineCell.find(id)
      transaction.each do |key, value|
        cell.settings["#{key}".to_sym] = value
        cell.updated_by = user_id
        cell.save
      end
      javascript += "$('.tru_container input[data-id=#{cell.id}]').closest('div').attr('class', '#{cell.get_css_attributes}');"
    end
    render js: javascript
  end

  def update
    @override = params[:override] unless params[:override].blank?

    cell = SsLineCell.find(params[:id])
    cell.update_attributes(cell_value: params[:value])
    render json: SettlementStatement.find(params[:ss_id]).as_json(include: {ordered_sections: {include: {ordered_lines: {include: [:ordered_cells]}}}})
  end
end