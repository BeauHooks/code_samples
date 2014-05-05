class TemplateSsSection < ActiveRecord::Base
  has_many :ss_lines, class_name: "TemplateSsLine", primary_key: :id, foreign_key: :ss_section_id
  belongs_to :settlement_statement, class_name: "TemplateSettlementStatement", primary_key: :id, foreign_key: :settlement_statement_id
  store :settings, accessors: [ :identifier ], coder: JSON

  accepts_nested_attributes_for :ss_lines, allow_destroy: true

  def ordered_lines
    order = self.line_order.split(",").map(&:to_i)
    self.ss_lines.index_by(&:id).slice(*order).values
  end

  def self.buyer_section
    where(name: "Buyer").first
  end

  def self.seller_section
    where(name: "Seller").first
  end
end
