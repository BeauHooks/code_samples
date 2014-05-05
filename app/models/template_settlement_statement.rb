class TemplateSettlementStatement < ActiveRecord::Base
  has_many :ss_sections, class_name: "TemplateSsSection", primary_key: :id, foreign_key: :settlement_statement_id
  has_many :ss_lines, through: :ss_sections
  has_many :ss_line_cells, through: :ss_lines
  has_many :ss_groups, class_name: "TemplateSsGroup", primary_key: :id, foreign_key: :settlement_statement_id
  has_one  :doc
  belongs_to :index, primary_key: "ID", foreign_key: "index_id"

  accepts_nested_attributes_for :ss_sections, allow_destroy: true

  def ordered_sections
    order = self.section_order.split(",").map(&:to_i)
    self.ss_sections.index_by(&:id).slice(*order).values
  end
end