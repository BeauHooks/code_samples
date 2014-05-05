class SettlementStatement < ActiveRecord::Base

  has_many :ss_sections
  has_one :buyer_section, class_name: "SsSection", conditions: "ss_sections.name = 'Buyer'"
  has_one :seller_section, class_name: "SsSection", conditions: "ss_sections.name = 'Seller'"
  has_many :ss_lines, through: :ss_sections
  has_many :ss_line_cells, through: :ss_lines
  has_many :payment_disbursements, through: :ss_lines
  has_many :ss_groups
  has_one  :doc
  belongs_to :index, primary_key: "ID", foreign_key: "index_id"

  accepts_nested_attributes_for :ss_sections, allow_destroy: true

  def self.create_from_template(template_type, settlement_statement)
    do_not_copy = ["id", "removed_by", "removed_at", "created_by", "updated_by", "created_at", "updated_at", "settlement_statement_id", "ss_section_id", "ss_line_id", "ss_group_id", "line_order", "cell_order"]
    template = TemplateSettlementStatement.where("ss_type = '#{template_type}'").first

    template.attributes.each do |key, value|
      settlement_statement[key] = value unless do_not_copy.include?(key)
    end
    ss = self.create(settlement_statement)

    groups = Hash.new
    template.ss_groups.each do |template_group|
      group = SsGroup.new(settlement_statement_id: ss.id)
      template_group.attributes.each do |key, value|
        group.send(key + "=", value) unless do_not_copy.include?(key)
      end
      group.save
      groups[group.name] = group
    end

    sections = []
    template.ordered_sections.each do |template_section|
      section = SsSection.new(settlement_statement_id: ss.id)
      template_section.attributes.each do |key, value|
        section.send(key + "=", value) unless do_not_copy.include?(key)
      end
      section.save
      sections << section.id

      lines = []
      template_section.ordered_lines.each do |template_line|
        line = SsLine.new(ss_section_id: section.id)
        template_line.attributes.each do |key, value|
          line.send(key + "=", value) unless do_not_copy.include?(key)
        end

        unless template_line.ss_group_id.blank?
          group = groups[template_line.ss_group.name]
          line.ss_group_id = group.id unless group.blank?
        end

        line.save
        lines << line.id

        cells = []
        template_line.ordered_cells.each do |template_cell|
          cell = SsLineCell.new(ss_line_id: line.id)
          template_cell.attributes.each do |key, value|
            cell.send(key + "=", value) unless do_not_copy.include?(key)
          end
          cell.save
          cells << cell.id
        end
        line.update_column("cell_order", cells.join(","))
      end
      section.update_column("line_order", lines.join(","))
    end
    ss.update_column("section_order", sections.join(","))
    ss.update_from_index
    return ss
  end

  def update_from_index
    # TODO: Improve this method with better data and Schedule A stuff. Tax status could come from central default set by an administrator.
    file = self.index
    self.update_column("tax_proration_date", file.COEDate || Time.now.to_s(:db))
    self.update_column("tax_status", "none")
    self.update_column("tax_total", 0)


  end

  def ordered_sections
    order = self.section_order.split(",").map(&:to_i)
    self.ss_sections.index_by(&:id).slice(*order).values
  end

  def update_hoa_proration_lines
    # TODO: Clean-up with method -DW
    start_date        = self.hoa_start_at
    end_date          = self.hoa_end_at
    hoa_due           = self.hoa_due
    hoa_amount        = self.hoa_amount
    buyers_line_size  = self.ss_sections.buyer_section.ordered_lines.size
    sellers_line_size = self.ss_sections.seller_section.ordered_lines.size

    if hoa_due == "annual"
      days_in_year  = (Time.now + 1.year).to_date.mjd - Time.now.to_date.mjd
      sellers_total  = (hoa_amount * ((end_date.to_date.mjd.to_f - start_date.to_date.mjd.to_f) / days_in_year.to_f)).round(2)
      buyers_total = hoa_amount - sellers_total
    else
      sellers_total  = (hoa_amount * (end_date.day.to_f / Time.days_in_month(end_date.month).to_f)).round(2)
      buyers_total = hoa_amount - sellers_total
    end

    new_records = []
    case self.hoa_applies
    when "charge_buyer-charge_seller"
      line, new_record = self.buyer_section.get("payee", "hoa_due")
      line.set({name: "Home Owner Association Dues", charges: buyers_total, credits: nil})
      new_records << line if new_record

      line, new_record = self.buyer_section.get("payee", "hoa_transfer")
      line.set({name: "Home Owner Association Transfer Fee", charges: nil, credits: nil}) if new_record
      new_records << line if new_record

      line, new_record = self.seller_section.get("payee", "hoa_due")
      line.set({name: "Home Owner Association Dues", charges: sellers_total, credits: nil})
      new_records << line if new_record
    when "charge_buyer-credit_seller"
      line, new_record = self.buyer_section.get("payee", "hoa_due")
      line.set({name: "Home Owner Association Dues", charges: buyers_total, credits: nil})
      new_records << line if new_record

      line, new_record = self.buyer_section.get("payee", "hoa_due")
      line.set({name: "Home Owner Association Transfer Fee", charges: nil, credits: nil}) if new_record
      new_records << line if new_record

      line, new_record = self.seller_section.get("payee", "hoa_due")
      line.set({name: "Home Owner Association Dues", charges: nil, credits: buyers_total})
      new_records << line if new_record
    else
      raise "HOA Condition doesn't exist"
    end
    return new_records
  end

  ###############################################################################
  # Extra functions for manual maintenance. Can remove when they are not necessary anymore.
  ###############################################################################

  def export_to_template
    do_not_copy = ["id", "removed_by", "removed_at", "created_by", "updated_by", "created_at", "updated_at", "settlement_statement_id", "ss_section_id", "ss_line_id", "ss_group_id", "line_order", "cell_order"]
    template = TemplateSettlementStatement.create(ss_type: "default", created_by: 231, updated_by: 231)

    groups = Hash.new
    self.ss_groups.each do |group|
      template_group = TemplateSsGroup.new(settlement_statement_id: template.id)
      group.attributes.each do |key, value|
        template_group.send(key + "=", value) unless do_not_copy.include?(key) || !template_group.attributes.include?(key)
      end
      template_group.save
      groups[template_group.name] = template_group
    end

    sections = []
    self.ordered_sections.each do |section|
      template_section = TemplateSsSection.new(settlement_statement_id: template.id)
      section.attributes.each do |key, value|
        template_section.send(key + "=", value) unless do_not_copy.include?(key) || !template_section.attributes.include?(key)
      end
      template_section.save
      sections << template_section.id

      lines = []
      section.ordered_lines.each do |line|
        template_line = TemplateSsLine.new(ss_section_id: template_section.id, created_by: 231, updated_by: 231)
        line.attributes.each do |key, value|
          template_line.send(key + "=", value) unless do_not_copy.include?(key) || !template_line.attributes.include?(key)
        end

        unless line.ss_group_id.blank?
          group = groups[line.ss_group.name]
          template_line.ss_group_id = group.id unless group.blank?
        end

        template_line.save
        lines << template_line.id

        cells = []
        line.ordered_cells.each do |cell|
          template_cell = TemplateSsLineCell.new(ss_line_id: template_line.id, created_by: 231, updated_by: 231)
          cell.attributes.each do |key, value|
            template_cell.send(key + "=", value) unless do_not_copy.include?(key) || !template_cell.attributes.include?(key)
          end

          template_cell.save
          cells << template_cell.id
        end
        template_line.update_column("cell_order", cells.join(","))
      end
      template_section.update_column("line_order", lines.join(","))
    end
    template.update_column("section_order", sections.join(","))
    return template
  end
end