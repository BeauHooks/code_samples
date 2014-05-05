class SsLineCell < ActiveRecord::Base
  belongs_to :ss_line
  belongs_to :ss_group

  store :settings, accessors: [ :width, :font_size, :font_style_italic, :font_style_bold, :resizable ], coder: JSON

  after_create :set_css_attributes
  after_save :create_payment, :update_proration_date

  scope :cname,      -> { where(cell_name: "name") }
  scope :payee_name, -> { where(cell_name: "payee_name") }
  scope :charges,    -> { where(cell_name: "charges") }
  scope :credits,    -> { where(cell_name: "credits") }
  scope :percent,    -> { where(cell_name: "percent") }

  FONT_SIZES = ["6pt", "7pt", "8pt", "9pt", "10pt", "11pt", "12pt"]
  RESIZABLE = ["payee_name", "payee_payee_name", "commission_amount", "commission_payee_name", "proration_name", "proration_amount"]
  CSS_ATTRIBUTES = ["width", "font_size", "font_style_bold", "font_style_italic"]

  def ss_group_id ; return self.ss_line.ss_group_id ; end

  def create_payment
    if ["payee_name", "charges", "credits", "amount", "poc"].include?(self.cell_name)
      #TODO: The info hash is temporary while we support the legacy HUD. This should actually pass the cell as a parameter instead
      info = Hash.new
      info["cell_name"] = self.cell_name
      info["cell_value_changed?"] = self.cell_value_changed?
      info["cell_value_was"] = self.cell_value_was

      self.ss_line.create_payment(info)
    end
  end

  def self.cell_font_size_options
    return FONT_SIZES.map{|s| [s, "tru_font_#{s}"]}
  end

  def initialize_ss_line_cell
    # self.css_attributes
  end

  def set_css_attributes
    if ["charges", "credits"].include?(self.cell_name)
      settings[:width] = "tru_2 tru_amount"
    else
      case "#{self.ss_line.line_type}_#{self.cell_name}"
      when "proration_date_description"
        settings[:width] = "tru_1"
      when "commission_name", "commission_total_name", "proration_date_start_date", "proration_date_end_date", "proration_payee_name"
        settings[:width] = "tru_2"
      when "proration_amount", "commission_amount"
        settings[:width] = "tru_3"
      when "payee_name"
        settings[:width] = "tru_5"
      when "proration_name", "proration_date_name"
        settings[:width] = "tru_6"
      when "commission_total_amount"
        settings[:width] = "tru_9"
      else
        case self.cell_name
        when "poc", "percent"
          settings[:width] = "tru_1"
        when "payee_name"
          settings[:width] = "tru_5"
        when  "payee_id"
          settings[:width] = "tru_hidden"
        else
          settings[:width] = "tru_11"
        end
      end
    end
    settings[:font_size] = "tru_font_7pt" if settings[:font_size].blank?
    save!
  end

  def get_css_attributes
    "#{settings[:width]} #{settings[:font_size]} #{settings[:font_style_bold]} #{settings[:font_style_italic]}"
  end

  def is_resizable?
    settings[:resizable] = RESIZABLE.include?("#{self.ss_line.line_type}_#{self.cell_name}")
  end

  def update_proration_date
    ss = self.ss_line.ss_section.settlement_statement
    return if self.cell_value.blank?
    if self.ss_line.ss_section.name == "Seller"
      case ss.tax_status
      when "credit"
        if self.cell_name == "start_date"
          split = self.cell_value.split("/")
          ss.tax_proration_date = "#{[split[1], split[0], split[2]].join('/')}"
        end
      when "debit"
        if self.cell_name == "end_date"
          split = self.cell_value.split("/")
          ss.tax_proration_date = "#{[split[1], split[0], split[2]].join('/')}"
        end
      else
        if self.cell_name == "start_date"
          split = self.cell_value.split("/")
          ss.tax_proration_date = "#{[split[1], split[0], split[2]].join('/')}"
        end
      end
    elsif self.ss_line.ss_section.name == "Buyer"
      case ss.tax_status
      when "credit"
        if self.cell_name == "start_date"
          split = self.cell_value.split("/")
          ss.tax_proration_date = "#{[split[1], split[0], split[2]].join('/')}"
        end
      when "debit"
        if self.cell_name == "start_date"
          split = self.cell_value.split("/")
          ss.tax_proration_date = "#{[split[1], split[0], split[2]].join('/')}"
        end
      else
        if self.cell_name == "start_date"
          split = self.cell_value.split("/")
          ss.tax_proration_date = "#{[split[1], split[0], split[2]].join('/')}"
        end
      end
    end
    ss.save
  end

  ###############################################################################
  # Extra functions for manual maintenance. Can remove when they are not necessary anymore.
  ###############################################################################

  def self.update_poc_attributes
    self.where("cell_name= 'poc'").each do |cell|
      cell.settings[:width] = "tru_1"
      cell.save
    end
  end

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
