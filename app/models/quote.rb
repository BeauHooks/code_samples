class Quote < ActiveRecord::Base
  establish_connection :rate_calc

  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(Version) ? v.id : v) } } }

  attr_accessible :underwriter,       :underwriter_id,    :borrower_name,     :seller_name,
                  :loan_number,       :loan_officer_info, :loan_amount_display,
                  :property_location, :purchase_amount_display, :version, :version_id,
                  :trust_deed_qty,    :warranty_deed_qty, :reconveyance_qty,  :assignment_qty

  has_many   :quote_endorsements, :dependent => :destroy
  belongs_to :underwriter
  belongs_to :gfe
  belongs_to :company, class_name: "Company", foreign_key: "company_id", primary_key: "CompanyID"
  belongs_to :version

  # Provide currency-formatted access to the amount fields
  def loan_amount_display
    self.loan_amount.to_currency
  end

  def purchase_amount_display
    self.purchase_amount.to_currency
  end

  def loan_amount_display=(amount)
    self.loan_amount = amount.is_a?(String) ? amount.gsub(/[$,]/, "") : amount
  end

  def purchase_amount_display=(amount)
    self.purchase_amount = amount.is_a?(String) ? amount.gsub(/[$,]/, "") : amount
  end

  # Retrive the RateLibrary calculator associated with this Quote
  def calculator
    @calculator ||= RateLibrary.load(self.version_id)
  end

  # Normalize the flat_rate boolean on assignment so that it can correctly
  # be read and treated as a boolean...
  def flat_rate=(val)
    if val.is_a?(String)
      if val =~ /^((t(rue)?)|(y(es)?))$/i or val.to_i != 0
        self[:flat_rate] = true
      else
        self[:flat_rate] = false
      end
    elsif val.is_a?(Numeric)
      self[:flat_rate] = !val.zero?
    elsif val
      self[:flat_rate] = true
    else
      self[:flat_rate] = false
    end
  end

  # Update our total fields to reflect current state
  def gfe_endorsement_total
  end

  def calculate_totals(port_or_company_id, is_port = true)
    self.trust_deed_qty    ||= 0
    self.warranty_deed_qty ||= 0
    self.reconveyance_qty  ||= 0
    self.assignment_qty    ||= 0
    self.trust_deed_total    = AppConfig.val(port_or_company_id, is_port, "trust_deed_fee")    * self.trust_deed_qty
    self.warranty_deed_total = AppConfig.val(port_or_company_id, is_port, "warranty_deed_fee") * self.warranty_deed_qty
    self.reconveyance_total  = AppConfig.val(port_or_company_id, is_port, "reconveyance_fee")  * self.reconveyance_qty
    self.assignment_total    = AppConfig.val(port_or_company_id, is_port, "assignment_fee")    * self.assignment_qty
    self.lenders_insurance_amount = calculator.calculate_rate(
      self.underwriter, 2,
      self.loan_amount, "Loan Policy",
      false, false, nil, nil,
      self.purchase_amount, "Home Owners Policy"
      )[:rate]

    # Total up for GFE line #4
    self.gfe_4_total =
      self.lenders_insurance_amount   +
      self.standard_settlement_amount +
      self.quote_endorsements.inject(0.0) { |sum, q| sum + (q.quoted_amount || 0.0) }

    self.endorsements_total =
      self.quote_endorsements.inject(0.0) { |sum, q| sum + (q.quoted_amount || 0.0) }

    # Calculate the owner's title insurance
    self.gfe_5_total = calculator.calculate_rate(
      self.underwriter, 1,
      self.purchase_amount, "Home Owners Policy",
      false, false, nil, nil,
      self.loan_amount, "Loan Policy"
      )

    # Calculate the total recording charges
    self.gfe_7_total =
      self.trust_deed_total    +
      self.warranty_deed_total +
      self.reconveyance_total  +
      self.assignment_total
  end
end
