class TemplateSsLineCell < ActiveRecord::Base
  belongs_to :ss_line, class_name: "TemplateSsLine", primary_key: :id, foreign_key: :ss_line_id
  belongs_to :ss_group, class_name: "TemplateSsGroup", primary_key: :id, foreign_key: :ss_group_id

  store :settings, accessors: [ :width, :font_size, :font_style_italic, :font_style_bold, :resizable ], coder: JSON

  scope :cname,      -> { where(cell_name: "name") }
  scope :payee_name, -> { where(cell_name: "payee_name") }
  scope :charges,    -> { where(cell_name: "charges") }
  scope :credits,    -> { where(cell_name: "credits") }
  scope :percent,    -> { where(cell_name: "percent") }

  ###############################################################################
  # Extra functions for manual maintenance. Can remove when they are not necessary anymore.
  ###############################################################################

  def self.update_identifiers
    cell_name_attributes = {
      "commission_charges" => "charges",
      "commission" => "amount",
      "commission_total" => "amount",
      "proration_credits" => "credits",
      "proration_charges" => "charges",
      "proration_amount" => "amount",
      "proration_start_date" => "start_date",
      "proration_end_date" => "end_date",
      "balance_due" => "name"
    }
    cell_names = cell_name_attributes.collect{|c, v| "'#{c}'"}

    self.where("cell_name IN (#{cell_names.join(",")})").each do |cell|
      cell.update_column("identifier", cell.cell_name)
      cell.update_column("cell_name", cell_name_attributes[cell.cell_name])
    end

    self.where("function IS NOT NULL").each do |cell|
      cell.update_column("identifier", cell.function)
      cell.update_column("function", nil)
    end
    exit
  end
end
