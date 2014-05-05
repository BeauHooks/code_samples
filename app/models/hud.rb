class Hud < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper

  after_save :update_related

  has_many :hud_lines, order: :number, dependent: :destroy
  has_many :hud_line_payments
  has_one  :gfe
  has_one  :doc,     foreign_key: "hud_id",    primary_key: "id"
  has_one  :index,   foreign_key: "FileID",    primary_key: "file_id"
  has_one  :invoice, foreign_key: "InvoiceID", primary_key: "invoice_id"

  accepts_nested_attributes_for :hud_lines, allow_destroy: true

  def resolve_ss_sort_order(section, sort_order, adjustment, user_id, exclude = nil)
    query = "sort_order >= #{sort_order} AND section = '#{section}'"
    query += " AND id != #{exclude.id}" unless exclude.blank?

    self.ss_lines.where(query).each do |line|
      line.update_attributes(sort_order: line.sort_order + adjustment, updated_by: user_id)
    end
  end

  def export(current_user)
    user_id = current_user.employee_id
    doc = self.doc
    file = self.index
    ss = SettlementStatement.create(index_id: file.ID, created_by: user_id, updated_by: user_id, ss_type: "default")
    section_order = []

    ["Buyer", "Seller"].each do |section|
      ss_section = SsSection.create(name: section, settlement_statement_id: ss.id)
      section_order << ss_section.id
      line_order = []
      condition = section == "Buyer" ? "number >= 3000 AND number < 4000" : "number >= 4000 AND number < 5000"
      self.hud_lines.where(condition).order("number ASC").each do |h_line|
        cell_order = []
        line = SsLine.new
        line.ss_section_id = ss_section.id
        line.line_type = h_line.type.sub(/ss_/, "").sub(/_custom/, "")
        line.side = section.downcase
        line.created_by = user_id
        line.updated_by = user_id
        line.save
        line_order << line.id

        case h_line.type.gsub("_custom", "")
        when "ss_header", "ss_normal", "ss_footer"
          attribute_list = ["name", "charges", "credits"]
        when "ss_proration_date"
          attribute_list = ["name", "start_date", "description", "end_date", "charges", "credits"]
        when "ss_proration" , "ss_commission_total"
         attribute_list = ["name", "amount", "charges", "credits"]
        when "ss_payee"
          attribute_list = ["name", "payee_name", "charges", "credits"]
        when "ss_commission"
          attribute_list = ["name", "amount", "payee_name", "percent", "charges", "credits"]
        else
          attribute_list = []
        end

        attribute_list.each do |key|
          cell = SsLineCell.new
          cell.ss_line_id = line.id
          cell.cell_name = key
          cell.data_type = HudLine.columns_hash[key].type #value.class.to_s

          case cell.data_type
          when "date"
            cell.cell_value = Date.strptime(h_line.send(key.to_sym).to_s, "%Y-%m-%d").strftime("%m/%d/%Y")
          else
            if line.line_type == "commission" && cell.cell_name == "name"
              cell.cell_value = "Commission >"
            elsif  line.line_type == "commission_total" && cell.cell_name == "name"
              cell.cell_value = "Total >"
            elsif line.line_type == "proration_date" && cell.cell_name == "description"
              cell.cell_value = "to"
            else
              cell.cell_value = h_line.send(key.to_sym)
            end
          end
          cell.created_by = user_id
          cell.updated_by = user_id
          cell.save
          cell_order << cell.id
        end
        line.cell_order = cell_order.join(",")
        line.save!
      end
      ss_section.line_order = line_order.join(",")
      ss_section.save!
    end
    ss.section_order = section_order.join(",")
    ss.save!
    doc.update_attributes(hud_id: nil, settlement_statement_id: ss.id)
  end

  def initialize(options={})
    # Set defaults
    options.reverse_merge!(
      type: "standard"
    )

    self.setup(options[:type])
  end

  def setup(hud_type = "standard")
    self.line_numbers_to_draw(hud_type).each do |n|
      self.hud_lines.build(:number => n)
    end
  end

  def borrower_details
    "#{self.borrower_name}\n#{self.borrower_address}\n#{self.borrower_city}, #{self.borrower_state} #{self.borrower_zip}"
  end

  def seller_details
    "#{self.seller_name}\n#{self.seller_address}\n#{self.seller_city}, #{self.seller_state} #{self.seller_zip}"
  end

  def lender_details
    "#{self.lender_name}\n#{self.lender_address}\n#{self.lender_city}, #{self.lender_state} #{self.lender_zip}"
  end

  def update_related
    if self.initial_loan_amount_changed?
      line = self.hud_lines.where("number = 800").first
      if line != nil
        line.amount = self.initial_loan_amount.to_f * line.percent.to_f/100 if line.percent.to_f > 0
        line.save
      end
    end
  end

  def update_hoa_proration_lines
    start_date  = self.hoa_start_at
    end_date    = self.hoa_end_at
    hoa_due     = self.hoa_due
    hoa_amount  = self.hoa_amount

    if hoa_due == "annual"
      days_in_year  = (Time.now + 1.year).to_date.mjd - Time.now.to_date.mjd
      sellers_total  = (hoa_amount * ((end_date.to_date.mjd.to_f - start_date.to_date.mjd.to_f) / days_in_year.to_f)).round(2)
      buyers_total = hoa_amount - sellers_total
    else
      sellers_total  = (hoa_amount * (end_date.day.to_f / Time.days_in_month(end_date.month).to_f)).round(2)
      buyers_total = hoa_amount - sellers_total
    end

    case self.hud_type
    when "standard"
      case self.hoa_applies
      when "charge_buyer-charge_seller"
        line = self.hud_lines.where(number: 109).first
        line.name = "Home Owner Association Dues"
        line.borrower_amount = buyers_total
        line.save

        line = self.hud_lines.where(number: 110).first
        line.name = "Home Owner Association Transfer Fee"
        line.save

        line = self.hud_lines.where(number: 513).first
        line.name = nil
        line.seller_amount = nil
        line.save

        line = self.hud_lines.where(number: 409).first
        line.name = "Home Owner Association Dues"
        line.seller_amount = sellers_total
        line.save
      when "charge_buyer-credit_seller"
        line = self.hud_lines.where(number: 109).first
        line.name = "Home Owner Association Dues"
        line.borrower_amount = buyers_total
        line.save

        line = self.hud_lines.where(number: 110).first
        line.name = "Home Owner Association Transfer Fee"
        line.save

        line = self.hud_lines.where(number: 409).first
        line.name = nil
        line.seller_amount = nil
        line.save

        line = self.hud_lines.where(number: 513).first
        line.name = "Home Owner Association Dues"
        line.seller_amount = sellers_total
        line.save
      end
    when "in-house"
      case self.hoa_applies
      when "charge_buyer-charge_seller"
        line = self.hud_lines.where(number: 3022).first
        line.name = "Home Owner Association Dues"
        line.type = "ss_normal"
        line.charges = buyers_total
        line.save

        line = self.hud_lines.where(number: 3023).first
        line.name = "Home Owner Association Transfer Fee"
        line.type = "ss_normal"
        line.save

        line = self.hud_lines.where(number: 4026).first
        line.name = "Home Owner Association Dues"
        line.type = "ss_normal"
        line.charges = sellers_total
        line.credits = nil
        line.save
      when "charge_buyer-credit_seller"
        line = self.hud_lines.where(number: 3022).first
        line.name = "Home Owner Association Dues"
        line.type = "ss_normal"
        line.charges = buyers_total
        line.save

        line = self.hud_lines.where(number: 3023).first
        line.name = "Home Owner Association Transfer Fee"
        line.type = "ss_normal"
        line.save

        line = self.hud_lines.where(number: 4026).first
        line.charges = nil
        line.save

        line = self.hud_lines.where(number: 4026).first
        line.name = "Home Owner Association Dues"
        line.type = "ss_normal"
        line.credits = sellers_total
        line.save
      end
    end
  end

  def update_tax_proration_lines
    unless self.tax_proration_date == nil
      proration_date       = self.tax_proration_date.to_s.split("-")
      month                = proration_date[1]
      day                  = proration_date[2]
      year                 = proration_date[0]
      next_year            = (year.to_i + 1).to_s
      db_date              = "#{year}-#{month}-#{day}"
      db_beginning_of_year = "#{year}-01-01"
      db_next_year         = "#{next_year}-01-01"

      if self.tax_total != nil
        total_days     = (12*30.4).round(0).to_f
        proration_days = (db_date.to_date.mjd - db_beginning_of_year.to_date.mjd).to_f
        seller_amount  = ( (proration_days/total_days).to_f * self.tax_total ).round(2)

        proration_days  = (db_next_year.to_date.mjd - db_date.to_date.mjd).to_f
        borrower_amount = ( (proration_days/total_days).to_f * self.tax_total ).round(2)
        prorate         = true
      else
        prorate = false
      end

      case self.hud_type
      when "standard"
        line = self.hud_lines.where("number = 901").first
        if line.start_date != self.tax_proration_date
          line.start_date = self.tax_proration_date
          line.save
        end

        tax_lines = ["107", "407", "211", "511"]

        case self.tax_status
        when "credit"
          keep_tax_lines     = ["107", "407"]
          line               = self.hud_lines.where("number = 407").first
          line.start_date    = db_date
          line.end_date      = db_next_year
          line.seller_amount = borrower_amount if prorate && line.group.nil?
          line.save

          line                 = self.hud_lines.where("number = 107").first
          line.start_date      = db_date
          line.end_date        = db_next_year
          line.borrower_amount = borrower_amount if prorate && line.group.nil?
          line.save
        when "debit"
          keep_tax_lines     = ["107", "511"]
          line               = self.hud_lines.where("number = 511").first
          line.start_date    = db_beginning_of_year
          line.end_date      = db_date
          line.seller_amount = seller_amount if prorate && line.group.nil?
          line.save

          line                 = self.hud_lines.where("number = 107").first
          line.start_date      = db_date
          line.end_date        = db_next_year
          line.borrower_amount = borrower_amount if prorate && line.group.nil?
          line.save
        else
          keep_tax_lines     = ["211", "511"]
          line               = self.hud_lines.where("number = 511").first
          line.start_date    = db_beginning_of_year
          line.end_date      = db_date
          line.seller_amount = seller_amount if prorate && line.group.nil?
          line.save

          line                 = self.hud_lines.where("number = 211").first
          line.start_date      = db_beginning_of_year
          line.end_date        = db_date
          line.borrower_amount = seller_amount if prorate && line.group.nil?
          line.save
        end

        remove_tax_lines = tax_lines - keep_tax_lines
        remove_tax_lines.each do |number|
          line                 = self.hud_lines.where("number = #{number}").first
          line.start_date      = nil
          line.end_date        = nil
          line.borrower_amount = nil
          line.seller_amount   = nil
          line.save
        end
      when "in-house"
        @tax_lines = ["4012", "4013", "3012", "3013"]
        case self.tax_status
        when "credit"
          line            = self.hud_lines.where("number = 4012").first
          line.start_date = db_date
          line.end_date   = db_next_year
          is_custom       = !line.name.blank?
          line.save

          line                 = self.hud_lines.where("number = 4013").first
          line.periodic_amount = self.tax_total
          line.credits         = seller_amount if prorate && !is_custom
          line.charges         = nil if prorate && !is_custom
          line.save

          line            = self.hud_lines.where("number = 3012").first
          line.start_date = db_date
          line.end_date   = db_next_year
          is_custom       = !line.name.blank?
          line.save

          line                 = self.hud_lines.where("number = 3013").first
          line.periodic_amount = self.tax_total
          line.charges         = seller_amount if prorate && !is_custom
          line.credits         = nil if prorate && !is_custom
          line.save
        when "debit"
          line            = self.hud_lines.where("number = 4012").first
          line.start_date = db_beginning_of_year
          line.end_date   = db_date
          is_custom       = !line.name.blank?
          line.save

          line                 = self.hud_lines.where("number = 4013").first
          line.periodic_amount = self.tax_total
          line.charges         = seller_amount if prorate && !is_custom
          line.credits         = nil if prorate && !is_custom
          line.save

          line            = self.hud_lines.where("number = 3012").first
          line.start_date = db_date
          line.end_date   = db_next_year
          is_custom       = !line.name.blank?
          line.save

          line                 = self.hud_lines.where("number = 3013").first
          line.periodic_amount = self.tax_total
          line.charges         = borrower_amount if prorate && !is_custom
          line.credits         = nil if prorate && !is_custom
          line.save
        else
          line            = self.hud_lines.where("number = 4012").first
          line.start_date = db_beginning_of_year
          line.end_date   = db_date
          is_custom       = !line.name.blank?
          line.save

          line                 = self.hud_lines.where("number = 4013").first
          line.periodic_amount = self.tax_total
          line.charges         = seller_amount if prorate && !is_custom
          line.credits         = nil if prorate && !is_custom
          line.save

          line            = self.hud_lines.where("number = 3012").first
          line.start_date = db_beginning_of_year
          line.end_date   = db_date
          is_custom       = !line.name.blank?
          line.save

          line                 = self.hud_lines.where("number = 3013").first
          line.periodic_amount = self.tax_total
          line.credits         = seller_amount if prorate && !is_custom
          line.charges         = nil if prorate && !is_custom
          line.save
        end

        county = self.index.file_doc_fields.where("tag = 'PROPERTY_COUNTY' AND doc_id = 0 AND is_active != 0").first.value rescue "Washington"
        lines  = ["3014", "4014"]
        lines.each do |number|
          line = self.hud_lines.where("number = #{number}").first
          line.name = "Note: Seller's portion of 2013 taxes #{number_to_currency(seller_amount, unit: "$")} paid directly to the #{county} County Treasurer"
          line.save
        end
      end
    end
  end

  def update_hud_invoice
    invoice = self.invoice
    total = 0.0
    if invoice != nil
      categories = ["ClosingFee", "Endorsements", "DocPrep", "ExchangeFee", "FedEx", "EscrowCol", "Recon", "RecFee", "LimRpt", "CancelFee", "Forclose", "Lit", "PlatFee", "LenderPol", "OwnerPol", "JuniorPol", "TransferTax", "CPLEndorsement"]
      # BEGIN TOTAL: Totals up all of the hud lines with invoice categories and stores the amount in the proper field on the invoice
      categories.each do |category|
        amount = self.hud_lines.where("invoice_category = '#{category}' AND (poc IS NULL OR poc = '') AND payee_id = #{self.index.Company} AND number != 1104").sum{|l| l.amount.to_f + l.borrower_amount.to_f + l.seller_amount.to_f + l.charges.to_f - l.credits.to_f}.to_f

        if self.hud_type == "standard"
          if category == "Endorsements"
            line = self.hud_lines.where("number = 1104 AND payee_id = #{self.index.Company}").first
            amount += line.endorsement_amount.to_f if line != nil
            logger.debug "Endorsements: #{amount}"
          elsif category == "LenderPol"
            line = self.hud_lines.where("number = 1104 AND payee_id = #{self.index.Company}").first
            amount += line.amount.to_f if line != nil
            logger.debug "LenderPol: #{amount}"
          end
        end

        invoice.send(category + "=", amount)
        total += amount
      end

      invoice.InvoiceTotal = total
      invoice.InvoiceBalance = total
      invoice.save
      # END TOTAL
    end
  end

  def get_fees
    file = self.index
    total_fees = 0
    self.hud_lines.where("payee_id = #{file.Company} AND number NOT IN ('704', '4001', '3001', '5001') AND NOT (number > 1103 AND number < 1200) AND name NOT LIKE '%Earnest Money%' AND name NOT LIKE '%Down Payment%' ").each do |line|
      case line.number
      when 100..300
        line_total = line.borrower_amount.to_f
      when 400..699
        line_total = line.seller_amount.to_f
      when 1102
        line_total = line.seller_amount.to_f
      when 700..1400
        line_total = line.amount.to_f + line.borrower_amount.to_f + line.seller_amount.to_f
      when 3000..5999
        line_total = line.amount.to_f + line.charges.to_f - line.credits.to_f
      else
        line_total = 0
      end
      total_fees += line_total
    end
    return total_fees
  end

  #
  # Calculate the Lender's anticipated wirez
  #
  def lender_wire
    hud_type = self.hud_type
    if hud_type == "standard"
      loan_amount = self.initial_loan_amount.to_f + self.hud_lines.where("number < 400 AND name = 'Lender Credit'").sum("amount")
      if loan_amount.nil? || loan_amount == 0
        "No Loan Amount"
      else
        lender_fees = 0
        self.hud_lines.where("number IN (803, 901, 902, 903, 1001, 1301) OR (number >= 805 AND number <= 820) AND description != '(from GFE #1)' ").each do |line|
          lender_fees += line.borrower_amount.to_f unless line.has_disbursement?
        end
        # line = self.hud_lines.where(number: 903).first
        # payment = line.has_disbursement? ? 0 : line.borrower_amount.to_f
        # return loan_amount + payment - lender_fees
        return loan_amount - lender_fees
      end
    elsif hud_type == "in-house"
      return "No ss"
    end
  end

  #
  # Get borrower amount from the HUD-1 for creating a wire
  #
  def borrower_wire
    hud_type = self.hud_type
    if hud_type == "standard"
      borrower_amount = self.hud_lines.where(number: 220).first.borrower_amount
      if borrower_amount.nil? || borrower_amount == 0
        borrower_amount = "No Borrower Amount"
      end
    elsif hud_type == "in-house"
      borrower_amount = self.hud_lines.where(number: 3000).first.charges
      if borrower_amount.nil? || borrower_amount == 0
        borrower_amount = "No Borrower Amount"
      end
    end
    return borrower_amount
  end

  # Returns the HUD line with the specified line number or nil if no line with
  # the specified number is associated with the HUD
  #
  # NOTE: will always return nil for unsaved/new HUD objects
  #
  def line_by_number(num)
    self.hud_lines.find(:first, :conditions => ["number = ?", num])
  end

  # For a given object, return a sorted list (with no duplicates) of all the
  # line numbers that should be drawn to render this HUD as a form. Allows you
  # to optionally include an array of your own extra line numbers that should
  # be included in the final list...
  #
  def line_numbers_to_draw(hud_type = "standard",extras = [])
    case hud_type
    when "standard"
      nums  = self.hud_lines.map { |l| l.number } + (extras & HudLine::LEGAL_LINES)
      nums += HudLine.get_parallel_lines(nums) + HudLine::STANDARD_ALWAYS_DRAWN
      nums.uniq.sort

    when "in-house"
      nums  = self.hud_lines.map { |l| l.number } + (extras)
      nums += HudLine::IN_HOUSE_ALWAYS_DRAWN
      nums.uniq.sort

    when "loan-in-house"
      nums  = self.hud_lines.map { |l| l.number } + (extras)
      nums += HudLine::LOAN_IN_HOUSE_ALWAYS_DRAWN
      nums.uniq.sort
    end
  end
  def j_lines_to_draw(extras = [])
    self.line_numbers_to_draw(extras) & HudLine::SECTION_J_LINES
  end
  def k_lines_to_draw(extras = [])
    self.line_numbers_to_draw(extras) & HudLine::SECTION_K_LINES
  end
  def l_lines_to_draw(extras = [])
    self.line_numbers_to_draw(extras) & HudLine::SECTION_L_LINES
  end
  def m_lines_to_draw(extras = [])
    self.line_numbers_to_draw(extras) & HudLine::SECTION_M_LINES
  end

  # Either returns the HUD line matching the specified number or a new, blank,
  # default line (defaults according to the specified line number).
  #
  # NOTE: This DOES NOT save any newly created lines!
  #
  def line_by_number_or_default(num)
    self.hud_lines.find(:first, :conditions => ["number = ?", num]) || self.hud_lines.build(:number => num)
  end

  # The amount/difference between the gfe_total and the hud_total
  #
  def gfe_to_hud_increase
    return 0.0 if self.hud_total.nil? or self.gfe_total.nil?
    self.hud_total - self.gfe_total
  end
  def gfe_to_hud_increase_percent
    return 0.0 if self.gfe_total.nil? or self.gfe_total == 0.0
    self.gfe_to_hud_increase / self.gfe_total
  end
end
