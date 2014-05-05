module SettlementStatementsHelper
  def get_cell(cell_type, f, section, line, cell, is_footer)
    render "settlement_statements/partials/cells/#{cell_type}", f: f, section: section, line: line, cell: cell, is_footer: is_footer
  rescue
    render "settlement_statements/partials/cells/normal", f: f, section: section, line: line, cell: cell, is_footer: is_footer
  end

  def payment_class(line)
    if line.payment_amount > 0
      if line.payment_amount - line.payment_disbursements.sum("amount") == 0
        "green"
      else
        "red"
      end
    else
      ""
    end
  end
end