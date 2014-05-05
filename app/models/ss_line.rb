class SsLine < ActiveRecord::Base
  belongs_to :settlement_statement
  belongs_to :ss_section
  has_many :ss_line_cells
  has_many :payment_disbursements, dependent: :destroy
  has_many :ss_poc_payments, class_name: "PaymentDisbursement", conditions: "funds_type = 'poc'"
  belongs_to :ss_group

  accepts_nested_attributes_for :ss_line_cells, allow_destroy: true

  after_save :update_related

  default_scope {where("ss_lines.is_active = -1")}

  def destroy
    self.update_attributes(is_active: 0)
    self.destroy_payment_disbursements
  end

  def update_related
    # Return if we're still creating the settlement statement
    return if self.ss_section.line_order.blank?

    if self.line_type_changed?
      self.destroy_payment_disbursements if self.get("payee_name").blank?
    end
  end

  def update_ss_group
    case self.line_type
    when "commission", "commission_total"
      order = SsSection.find(self.ss_section_id).line_order.split(",")
      my_index = order.index("#{self.id}")
      return if my_index.blank?

      if my_index > 0
        before = SsLine.find(order[my_index - 1])
        self.set_ss_group_id(before.ss_group_id) and return if before.line_type == "commission"
      end

      if my_index < order.size - 1
        after = SsLine.find(order[my_index + 1])
        self.set_ss_group_id(after.ss_group_id) and return if self.line_type != "commission_total" && ["commission", "commission_total"].include?(after.line_type)
      end
      self.set_ss_group_id("new", "commissions")
    else
      case self.line_sub_type
      when "hoa_due", "hoa_transfer"
        ss = self.ss_section.settlement_statement
        group_mate = ss.ss_lines.where("line_sub_type IN ('hoa_due', 'hoa_transfer') AND ss_group_id IS NOT NULL").first
        self.set_ss_group_id(group_mate.ss_group_id) and return unless group_mate.blank?
        self.set_ss_group_id("new", "hoa") and return
      else
        self.update_column("ss_group_id", nil) and return
      end
    end
  end

  def set_ss_group_id(id, name = nil)
    if id == "new"
      ss_group = SsGroup.create(settlement_statement_id: self.ss_section.settlement_statement_id, name: name)
      id = ss_group.id
    end

    self.update_column("ss_group_id", id)
  end

  def ordered_cells
    order = self.cell_order.split(",").map(&:to_i)
    self.ss_line_cells.index_by(&:id).slice(*order).values
  end

  SS_LINE_AVAILABLE_TYPES = ["commission", "commission_total", "header", "normal", "payee", "proration"]
  DATA_TYPES = {"name" => "string", "header" => "string", "payee_name" => "string", "amount" => "decimal", "charges" => "decimal", "credits" => "decimal", "start_date" => "date", "end_date" => "date", "percent" => "decimal", "description" => "string"}
  DEFAULT_VALUES = {"commission_name" => "Commission >", "commission_total_name" => "Total >", "proration_date_description" => "to"}

  def self.line_type_options; return SS_LINE_AVAILABLE_TYPES.map{|t| [t.titleize, t]} ; end

  def update_type
    cell_order = []
    case self.line_type
    when "header", "normal", "footer"
      cell_list = ["name", "charges", "credits"]
    when "proration_date"
      cell_list = ["name", "start_date", "description", "end_date", "charges", "credits"]
    when "proration"
      cell_list = ["name", "amount", "payee_name", "charges", "credits"]
    when "commission"
      cell_list = ["name", "amount", "payee_name", "percent", "charges", "credits"]
    when "commission_total"
      cell_list = ["name", "amount", "charges", "credits"]
    when "payee"
      cell_list = ["name", "payee_name", "poc", "charges", "credits"]
    else
      exit #TO-DO: Do some error handling here.
    end

    self.ss_line_cells.where("cell_name NOT IN ('#{cell_list.join("', '")}') AND is_active != 0").each do |cell|
      cell.update_attributes(is_active: 0)
    end

    i = 0
    existing = SsLine.find(self.id).ss_line_cells.to_a.each_with_object({}){ |c, h| h[c.cell_name] = c }
    cell_list.each do |key|
      unless existing[key].blank?
        existing[key].cell_value = DEFAULT_VALUES["#{self.line_type}_#{key}"] unless DEFAULT_VALUES["#{self.line_type}_#{key}"].blank?
        existing[key].update_attributes(is_active: -1, updated_by: self.updated_by)
        cell_order << existing[key].id
        existing[key].set_css_attributes
      else
        case self.line_type
        when "commission"
          name = "Commission >" if key == "name"
        when "commission_total"
          name = "Total >" if key == "name"
        end
        cell = SsLineCell.create(ss_line_id: self.id, cell_name: key, cell_value: (DEFAULT_VALUES["#{self.line_type}_#{key}"] || nil), data_type: (DATA_TYPES[key] || "string"), is_active: -1, created_by: self.updated_by, updated_by: self.updated_by)
        cell_order << cell.id
      end
    end
    self.update_ss_group
    self.update_column("cell_order", cell_order.join(","))
    self.destroy_payment_disbursements if self.get("payee_name").blank?
  end

  def create_payment(cell)
    PaymentDisbursement.handle(self, cell)
  end

  def destroy_payment_disbursements
    self.payment_disbursements.each do |payment_disbursement|
      payment_disbursement.destroy
    end
  end

  def payment_amount
    case self.line_sub_type || self.line_type
    when "downpayment"
      # Payment is updated from buyer's side so we just return zero here.
      return 0.0 if self.ss_section.name == "Seller" || self.get("poc").blank?
      seller = SsLine.where("line_sub_type = '#{self.line_sub_type}' AND ss_group_id = #{self.ss_group_id} AND id != #{self.id}").first unless self.ss_group_id.blank?

      # Multiply by negative 1 so we know to subtract this from the payment
      if seller.blank?
        return -1 * self.get("credits").to_f
      else
        return -1 * (self.get("credits").to_f - seller.get("charges").to_f)
      end
    when "payee"
      return self.get("poc").blank? ? self.get("charges").to_f : 0
    when "commission"
      return self.get("amount").to_f
    when "proration"
      # Payment is updated from seller's side so we just return zero here.
      return 0.0 if self.ss_section.name == "Buyer"
      buyer = SsLine.where("line_type = '#{self.line_type}' AND ss_group_id = #{self.ss_group_id} AND id != #{self.id}").first unless self.ss_group_id.blank?
      amount = self.ss_group_id.blank? || buyer.blank? ? self.get("charges").to_f - self.get("credits").to_f : self.get("charges").to_f - self.get("credits").to_f + buyer.get("charges").to_f - buyer.get("credits").to_f
      return amount > 0 ? amount : 0
    else
      return 0.0
    end
  end

  def get(name)
    cell = self.ss_line_cells.where("cell_name = '#{name}'").first
    return nil if cell.blank?
    case cell.data_type
    when "decimal"
      return cell.cell_value.to_s.gsub(/,/, "").to_f
    when "integer"
      return cell.cell_value.to_s.gsub(/,/, "").to_i
    else
      return cell.cell_value.to_s
    end
  end

  def set(pairs)
    pairs.each do |key, value|
      cell = self.ss_line_cells.where("cell_name = '#{key}'").first
      cell.update_attributes(cell_value: value) unless cell.blank?
    end
  end

  def number
    return "#{self.ss_section.name.to_s[0]} #{self.ss_section.line_order.split(",").index("#{self.id}") + 1}"
  end

  ###############################################################################
  # Extra functions for manual maintenance. Can remove when they are not necessary anymore.
  ###############################################################################

  # Add a poc cell to all payee lines
  def self.add_poc_cells
    self.where("line_type = 'payee'").each do |line|
      next if line.cell_order.blank?
      payee = line.ss_line_cells.where("cell_name = 'payee_name'").first
      next if payee.blank?
      order = line.cell_order.split(",")
      cell = SsLineCell.new(ss_line_id: line.id, cell_name: "poc", data_type: "string", is_active: -1, created_by: 231, updated_by: 231)
      cell.settings[:width] = "tru_1"
      cell.save
      new_order = order[0..1] + [cell.id] + order[2..-1]
      line.update_column("cell_order", new_order.join(","))

      payee.settings[:width] = "tru_7"
      payee.save
    end
  end

  # Update all lines with their corresponding cells' ss_group_id
  def self.get_ss_group_ids
    self.where("id IS NOT NULL").each do |line|
      group_cell = line.ss_line_cells.where("ss_group_id IS NOT NULL AND ss_group_id != ''").first
      next if group_cell.blank?
      line.update_column("ss_group_id", group_cell.ss_group_id)
    end

    TemplateSsLine.where("id IS NOT NULL").each do |line|
      group_cell = line.ss_line_cells.where("ss_group_id IS NOT NULL AND ss_group_id != ''").first
      next if group_cell.blank?
      line.update_column("ss_group_id", group_cell.ss_group_id)
    end
  end

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
