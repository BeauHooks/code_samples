class TemplateSsLine < ActiveRecord::Base
  belongs_to :settlement_statement, class_name: "TemplateSettlementStatement", primary_key: :id, foreign_key: :settlement_statement_id
  belongs_to :ss_section, class_name: "TemplateSsSection", primary_key: :id, foreign_key: :ss_section_id
  has_many :ss_line_cells, class_name: "TemplateSsLineCell", primary_key: :id, foreign_key: :ss_line_id
  belongs_to :ss_group, class_name: "TemplateSsGroup", primary_key: :id, foreign_key: :ss_group_id

  accepts_nested_attributes_for :ss_line_cells, allow_destroy: true

  def ordered_cells
    order = self.cell_order.split(",").map(&:to_i)
    self.ss_line_cells.index_by(&:id).slice(*order).values
  end

  ###############################################################################
  # Extra functions for manual maintenance. Can remove when they are not necessary anymore.
  ###############################################################################

  def self.update_identifiers
    line_type_attributes = {
      "hoa_due" => "payee",
      "hoa_transfer" => "payee",
      "downpayment" => "payee",
      "sales_price" => "header"
    }
    line_types = line_type_attributes.collect{|c, v| "'#{c}'"}

    self.where("line_type IN (#{line_types.join(",")})").each do |line|
      line.update_column("line_sub_type", line.line_type)
      line.update_column("line_type", line_type_attributes[line.line_type])
    end

    exit
  end
end
