class TemplateSsGroup < ActiveRecord::Base
  has_many :ss_line_cells, class_name: "TemplateLineCell", primary_key: :id, foreign_key: :ss_group_id
  belongs_to :settlement_statement, class_name: "TemplateSettlementStatement", primary_key: :id, foreign_key: :settlement_statement_id
end