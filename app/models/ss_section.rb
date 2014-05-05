class SsSection < ActiveRecord::Base
  has_many :ss_lines
  belongs_to :settlement_statement
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

  def get(line_type, line_sub_type)
    line = self.ss_lines.where("line_type = '#{line_type}' AND line_sub_type = '#{line_sub_type}'").first
    if line.blank?
      line_order = self.line_order.split(",")
      index = line_order.size - 4

      line = SsLine.create(ss_section_id: self.id, line_type: line_type, line_sub_type: line_sub_type)
      line_order.insert(index, line.id)
      self.update_column("line_order", line_order.join(","))
      line.update_type
      return line, true
    end
    return line, false
  end
end
