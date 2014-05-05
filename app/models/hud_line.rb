class HudLine < ActiveRecord::Base
  @@skip_calculations = false
  @@skip_create_payment = false
  @@run_once = false
  self.inheritance_column = :sti_unused

  before_create :prevent_calculations
  before_create :prevent_create_payment
  after_save :calculate_hud_by_line, unless: :skip_calculations
  after_save :create_payment, unless: :skip_create_payment
  after_save :update_payment

  attr_accessible :number

  belongs_to :hud
  has_many :hud_line_payments, dependent: :destroy
  has_many :payment_disbursements, dependent: :destroy
  has_many :hud_poc_payments, class_name: "PaymentDisbursement", conditions: "funds_type = 'poc'"
  has_one :update_employee,  class_name: "Employee", foreign_key: "ID", primary_key: "updated_by"

  # These define, by section, all the possible line numbers that are legal
  SECTION_J_LINES =   (100..120).to_a + (200..220).to_a + (300..303).to_a
  SECTION_K_LINES =   (400..420).to_a + (500..520).to_a + (600..603).to_a
  SECTION_L_LINES = ( 700..1400).to_a
  SECTION_M_LINES = (2000..2003).to_a + (2100...2300).to_a
  LEGAL_LINES     = SECTION_J_LINES + SECTION_K_LINES + SECTION_L_LINES + SECTION_M_LINES

  # There are the hud line numbers that always get drawn on a form, whether an
  # entry exists in the database or not. Note that all from 2000 and up are
  # custom line numbers, assigned by us
  STANDARD_ALWAYS_DRAWN = ( 100..112 ).to_a + [120] + (200..220).to_a + (300..303).to_a +
                 ( 400..412 ).to_a + [420] + (500..520).to_a + (600..603).to_a +
                 ( 700..705 ).to_a + ( 800..808 ).to_a + ( 900..904 ).to_a +
                 (1000..1007).to_a + (1100..1109).to_a + (1200..1206).to_a +
                 (1300..1305).to_a + [1400] +
                 (2000..2004).to_a + (2100..2107).to_a + (2200..2205).to_a

  IN_HOUSE_ALWAYS_DRAWN = ( 3000..3027 ).to_a + ( 3096..3099 ).to_a + ( 4000..4027 ).to_a + ( 4096..4099 ).to_a

  LOAN_IN_HOUSE_ALWAYS_DRAWN = ( 5000..5027 ).to_a + ( 5096..5099 ).to_a

  DEFAULT_LINE_TYPES = {
    :jk_header      => [100, 200, 300, 400, 500, 600],
    :jk_footer      => [120, 220,      420, 520     ],
    :jk_checkbox    => [303, 603                    ],
    :jk_normal      => [101, 102, 103, 201, 202, 203, 301, 401, 402, 501, 502, 503, 601],
    :jk_inverse     => [302, 602],
    :jk_proration   => [106, 107, 108, 210, 211, 212, 406, 407, 408, 510, 511, 512],
    :jk_disbursement => [104, 105, 206, 207, 208, 209, 404, 405, 504, 505, 506, 507, 508, 509],
    :l_main_header  => [700],
    :l_main_payee   => [701, 702],
    :l_normal       => [703],
    :l_header       => [800, 900, 1000, 1100, 1200, 1300],
    :l_footer       => [1400],
    :l_payee_amount => [801, 1102],
    :l_amount_desc  => [802, 1107, 1108],
    :l_descriptive  => [705, 803, 1001, 1101, 1103, 1201, 1203, 1301],
    :l_payee        => [804, 805, 806, 807],
    :l_inverse      => [1007],
    :l_amount       => [1104, 1105, 1106],
    :l_daily_int    => [901],
    :l_mort_ins     => [902],
    :l_home_ins     => [903],
    :l_periodic     => [1002, 1003, 1004, 1005, 1006],
    :l_dmr          => [1202],
    :l_dm           => [1204, 1205],
    :m_normal       => [2000, 2001, 2002, 2003, 2100, 2101, 2102, 2103, 2104, 2105, 2106, 2107, 2200, 2202],
    :m_periodic     => [2201],
    :ss_header    => [3000, 3003, 3011, 4000, 4003, 4011, 5000, 5003, 5011, 5016],
    :ss_payee   => [3001, 4001],
    :ss_normal    => [3004, 3005, 3006, 3007, 3008, 3009,  3014, 3015, 3017, 3018, 3022, 4004, 4005, 4006, 4007, 4008, 4009, 4014, 4015, 4017, 4026, 4018, 5001, 5004, 5005, 5006, 5007, 5008, 5009,  5014, 5015],
    :ss_proration_date    => [3012, 4012, 5012],
    :ss_proration  => [3013, 4013, 5013],
    :ss_footer => [3096, 3097, 3098, 3099, 4096, 4097, 4098, 4099, 5096, 5097, 5098, 5099]
  }

  DEFAULT_LINE_GROUPS = {
    :ss_proration => [3012, 3013, 4012, 4013, 5012, 5013]
  }

  DEFAULT_LINE_NAMES = {
     100 => "Gross Amount Due from Borrower",
     101 => "Contract sales price",
     102 => "Personal property",
     103 => "Settlement charges to borrower (line 1400)",
     104 => "Payoff to",
     105 => "Payoff to",
     106 => "City/town taxes",
     107 => "County taxes",
     108 => "Assessments",
     109 => "Home Owner Association Dues",
     110 => "Home Owner Association Transfer Fee",
     120 => "Gross Amount Due from Borrower",
     200 => "Amounts Paid by or in Behalf of Borrower",
     201 => "Deposit or earnest money",
     202 => "Principal amount of new loan(s)",
     203 => "Existing loan(s) taken subject to",
     204 => "Lender Credit",
     210 => "City/town taxes",
     211 => "County taxes",
     212 => "Assessments",
     220 => "Total Paid by/for Borrower",
     300 => "Cash at Settlement from/to Borrower",
     301 => "Gross amount due from borrower (line 120)",
     302 => "Less amounts paid by/for borrower (line 220)",
     303 => "Cash",
     400 => "Gross Amount Due to Seller",
     401 => "Contract sales price",
     402 => "Personal property",
     406 => "City/town taxes",
     407 => "County taxes",
     408 => "Assessments",
     420 => "Gross Amount Due to Seller",
     500 => "Reductions In Amount Due to Seller",
     501 => "Excess deposit (see instructions)",
     502 => "Settlement charges to seller (line 1400)",
     503 => "Existing loan(s) taken subject to",
     # 504 => "Payoff of first mortgage loan",
     # 505 => "Payoff of second mortgage loan",
     504 => "Payoff to",
     505 => "Payoff to",
     510 => "City/town taxes",
     511 => "County taxes",
     512 => "Assessments",
     520 => "Total Reduction Amount Due Seller",
     600 => "Cash at Settlement to/from Seller",
     601 => "Gross amount due to seller (line 420)",
     602 => "Less reductions in amount due seller (line 520)",
     603 => "Cash",
     700 => "Total Real Estate Broker Fees",
     703 => "Commission paid at settlement",
     704 => "Earnest Money",
     800 => "Items Payable in Connection with Loan",
     801 => "Our origination charge",
     802 => "Your credit or charge (points) for the specific interest rate chosen",
     803 => "Your adjusted origination charges",
     804 => "Appraisal fee to",
     805 => "Credit report to",
     806 => "Tax service to",
     807 => "Flood certification",
     900 => "Items Required by Lender to Be Paid in Advance",
     901 => "Daily interest charges from",
     902 => "Mortgage insurance premium",
     903 => "Homeowner's Insurance",
    1000 => "Reserves Deposited with Lender",
    1001 => "Initial deposit for your escrow account",
    1002 => "Homeowner's insurance",
    1003 => "Mortgage insurance",
    1004 => "Property taxes",
    1007 => "Aggregate Adjustment",
    1100 => "Title Charges",
    1101 => "Title services and lender's title insurance",
    1102 => "Settlement or closing fee",
    1103 => "Owner's title insurance",
    1104 => "Lender's title insurance",
    1105 => "Lender's title policy limit",
    1106 => "Owner's title policy limit",
    1107 => "Agent's portion of the total title insurance premium",
    1108 => "Underwriter's portion of the total title insurance premium",
    1200 => "Government Recording and Transfer Charges",
    1201 => "Government recording charges",
    1202 => "Government recording charges",
    1203 => "Transfer taxes",
    1204 => "City/County tax/stamps",
    1205 => "State tax/stamps",
    1300 => "Additional Settlement Charges",
    1301 => "Required services that you can shop for",
    1400 => "Total Settlement Charges (enter on lines 103, Section J and 502, Section K)",
    2000 => "Our origination charge",
    2001 => "Your credit or charge (points) for the specific interest rate chosen",
    2002 => "Your adjusted origination charges",
    2003 => "Transfer taxes",
    2100 => "Government recording charges",
    2101 => "Appraisal Fee",
    2102 => "Credit Report",
    2103 => "Tax Service Fee",
    2104 => "Flood Certification",
    2105 => "Up-front Mortgage Insurance Premium",
    2106 => "Title Services and Lender's title insurance",
    2107 => "Owners Title Insurance",
    2200 => "Initial deposit for your escrow account",
    2201 => "Daily interest charges",
    2202 => "Homeowner's insurance",
    3000 => "SALES PRICE",
    3001 => "Down Payment",
    3003 => "EXPENSES:",
    3004 => "Title insurance premium",
    3005 => "Recording fee",
    3006 => "Closing fee",
    3007 => "Escrow closing fee",
    3008 => "Overnight mail/Processing fee/Wire fee",
    3009 => "Additional documents/Reconveyance",
    3011 => "TAX PRORATIONS:",
    3013 => "Taxes for the year #{Time.now.strftime("%Y")}:",
    3014 => "NOTE: Seller's portion of #{Time.now.strftime("%Y")} taxes paid directly to the {{PROPERTY_COUNTY_TEXT}} County Treasurer",
    3015 => "by {{COMPANY_NAME_TEXT}}",
    3017 => "Buyers are responsible for insurance as of date of closing.",
    3018 => "Southern Utah Title Company will not be held liable.",
    3022 => "Home Owner Association Dues",
    3023 => "Home Owner Association transfer fee",
    3096 => "Sub-Totals",
    3097 => "Balance Due From Buyer",
    3099 => "TOTALS",
    4000 => "SALES PRICE",
    4001 => "Down Payment",
    4003 => "EXPENSES:",
    4004 => "Title insurance premium",
    4005 => "Recording fee",
    4006 => "Closing fee",
    4007 => "Escrow closing fee",
    4008 => "Overnight mail/Processing fee/Wire fee",
    4009 => "Additional documents/Reconveyance",
    4011 => "TAX PRORATIONS:",
    4013 => "Taxes for the year #{Time.now.strftime("%Y")}:",
    4014 => "NOTE: Seller's portion of #{Time.now.strftime("%Y")} taxes paid directly to the {{PROPERTY_COUNTY_TEXT}} County Treasurer",
    4015 => "by {{COMPANY_NAME_TEXT}}",
    4017 => "Buyers are responsible for insurance as of date of closing.",
    4018 => "Southern Utah Title Company will not be held liable.",
    4026 => "Home Owner Association Dues",
    4027 => "Home Owner Association transfer fee",
    4096 => "Sub-Totals",
    4097 => "Balance Due To Seller(s)",
    4099 => "TOTALS",
    5000 => "LOAN AMOUNT",
    5001 => "Borrower Deposit",
    5003 => "TITLE EXPENSES PAID AT CLOSING:",
    5004 => "Title insurance premium",
    5005 => "Recording and Processing fee",
    5006 => "Closing fee",
    5007 => "Collection Escrow Doc Fees",
    5008 => "Overnight Mail/Processing Fee/Wire Fee",
    5009 => "Additional Documents/Reconveyance",
    5011 => "TAX PRORATIONS:",
    5013 => "Taxes for #{Time.now.strftime("%Y")}:",
    5014 => "(#{Time.now.strftime("%Y")} taxes based on parent parcel.)",
    5016 => "EXPENSES/COSTS ASSOCIATED WITH THE LOAN:",
    5017 => "Origination Fee",
    5018 => "Loan Discount",
    5019 => "Appraisal Fee",
    5020 => "Credit Report",
    5096 => "Sub-Totals",
    5097 => "Balance Due",
    5099 => "TOTALS"
  }

  DEFAULT_LINE_DESCRIPTIONS = {
     801 => "(from GFE #1)",
     802 => "(from GFE #2)",
     803 => "(from GFE A)",
     804 => "(from GFE #3)",
     805 => "(from GFE #3)",
     806 => "(from GFE #3)",
     807 => "(from GFE #3)",
     901 => "(from GFE #10)",
     902 => "(from GFE #3)",
     903 => "(from GFE #11)",
    1001 => "(from GFE #9)",
    1101 => "(from GFE #4)",
    1103 => "(from GFE #5)",
    1201 => "(from GFE #7)",
    1203 => "(from GFE #8)",
    1301 => "(from GFE #6)",
    2000 => "801",
    2001 => "802",
    2002 => "803",
    2003 => "1203",
    2100 => "1201",
    2101 => "804",
    2102 => "805",
    2103 => "806",
    2104 => "807",
    2105 => "902",
    2106 => "1101",
    2107 => "1103",
    2200 => "1001",
    2201 => "901",
    2202 => "903"
  }

  DEFAULT_LINE_AMOUNTS = {
    3096 => 0.00,
    3097 => 0.00,
    3099 => 0.00,
    4096 => 0.00,
    4097 => 0.00,
    4099 => 0.00,
    5096 => 0.00,
    5097 => 0.00,
    5099 => 0.00
  }

  NO_TOUCH = ["id", "hud_id", "number", "created_by", "created_at", "updated_at", "updated_by"]

  # Given a list of line numbers, return another list of line numbers. The new
  # list will include an entry for each item in the original list that has a
  # "parallel" line number: one in the J or K section that is drawn
  # horizontally next to it. If no parallels found returns an empty list.
  def self.get_parallel_lines(nums)
    nums.map do |n|
      SECTION_J_LINES.include?(n) ? n+300 : (SECTION_K_LINES.include?(n) ? n-300 : nil)
    end.reject { |n| n.nil? }.uniq.sort
  end

  # Smart constructor allows the appropriate type of HUD line to be created if
  # the line number is passed during construction...
  def initialize(*args, &block)
    super
    #if LEGAL_LINES.include?(self.number)
      #
      # Set the line's type if it has a default and isn't already set
      #
      if self.type.nil?
        DEFAULT_LINE_TYPES.each do |name, numbers|
          if numbers.include?(self.number)
            self.type = name.to_s
            break
          end
        end
      end

      if self.type.nil?
        case self.number
        when 100..700
          self.type = "jk_normal"
        when 700..1400
          self.type = "l_disbursement"
        when 3000...6000
          self.type = "ss_payee"
        end
      end

      if self.type == "ss_proration"
        self.periods = 12
        self.description = "Months"
      end

      # Set the lines's group if it has a default and isn't already set
      if self.group.nil?
        DEFAULT_LINE_GROUPS.each do |name, numbers|
          if numbers.include?(self.number)
            self.group = name.to_s
            break
          end
        end
      end

      # Set the line's name if it has a default and isn't already set
      self.name = DEFAULT_LINE_NAMES[self.number] if self.name.nil? and DEFAULT_LINE_NAMES.has_key?(self.number)

      # Set the line's description if it has a default and isn't already set
      self.description = DEFAULT_LINE_DESCRIPTIONS[self.number] if self.description.nil? and DEFAULT_LINE_DESCRIPTIONS.has_key?(self.number)

      # Set the line's default amount to prevent methods being called on nil
      self.charges = DEFAULT_LINE_AMOUNTS[self.number] if self.charges.nil? and DEFAULT_LINE_AMOUNTS.has_key?(self.number)
      self.credits = DEFAULT_LINE_AMOUNTS[self.number] if self.credits.nil? and DEFAULT_LINE_AMOUNTS.has_key?(self.number)
    #end
    @@skip_calculations == true
  end

  def revert_to_default
    self.attributes.each do |key, value|
      unless NO_TOUCH.include?(key) || value == nil
        self.send(key + "=", nil)
      end
    end

    DEFAULT_LINE_TYPES.each do |name, numbers|
      if numbers.include?(self.number)
        self.type = name.to_s
        break
      end
    end

    if self.type.nil?
      case self.number
      when 100..700
        self.type = "jk_normal"
      when 700..1400
        self.type = "l_disbursement"
      when 3000...6000
        self.type = "ss_payee"
      end
    end

    if self.type == "ss_proration"
      self.periods = 12
      self.description = "Months"
    end

    DEFAULT_LINE_GROUPS.each do |name, numbers|
      if numbers.include?(self.number)
        self.group = name.to_s
        break
      end
    end

    self.name = DEFAULT_LINE_NAMES[self.number] if self.name.nil? and DEFAULT_LINE_NAMES.has_key?(self.number)
    self.description = DEFAULT_LINE_DESCRIPTIONS[self.number] if self.description.nil? and DEFAULT_LINE_DESCRIPTIONS.has_key?(self.number)
    self.save
  end

  def prevent_calculations
    @@skip_calculations = true
  end

  def prevent_create_payment
    @@skip_create_payment = true
  end

  # These are helper methods to access the "to_party" field in a context-
  # sensative way (to see if we're talking about
  def to_borrower?
    self.number == 303 and self.to_party?
  end

  def from_borrower?
    self.number == 303 and not self.to_party.nil? and not self.to_party?
  end

  def to_seller?
    self.number == 603 and self.to_party?
  end

  def from_seller?
    self.number == 603 and not self.to_party.nil? and not self.to_party?
  end

  # Returns the value "to_party" should have for the first checkbox to be
  # considered "checked"
  def first_checked_value
    self.number == 303 ? false : true
  end

  # Returns the value "to_party" should have for the second checkbox to be
  # considered "checked"
  def second_checked_value
    self.number == 603 ? false : true
  end

  # Calculate lender's anticipated wire
  def lender_wire

  end

  def has_disbursement?
    payment = self.hud_line_payments.first
    return false if payment.blank?
    return !payment.check_working.blank?
  end

  # TODO: Update this with all of the payment rules
  def payment_amount
    # return 0 if !self.poc.blank? && !(self.number == 704 || self.number == 4001)

    # Sets amount to zero so payment is deleted if payment is to lender within 800 Section
    return 0 if self.number > 800 && self.number < 900 && self.payee_id == hud.hud_lines.where("number = 801").first.payee_id && hud.hud_lines.where("number = 801").first.payee_id != nil

    # Sets amount to zero if tax status is not debit
    return 0 if hud.tax_status != "debit" && [107, 207, 407, 511].include?(self.number)

    # No payment if to company or in 500 section
    return 0 if (self.name == 'Earnest Money' || self.name == 'Down Payment') && (self.payee_id == self.company_id || self.number < 700)

    return 0 if (self.number > 1300 && self.number < 1400 && self.borrower_amount.to_f <= 0 && self.seller_amount.to_f <= 0)
    return 0 if (self.number > 800 && self.number < 900 && self.borrower_amount.to_f <= 0 && self.seller_amount.to_f <= 0)
    return 0 if self.payee_id == self.company_id && self.number > 1103 && self.number < 1200 && self.borrower_amount.to_f == 0 && self.seller_amount.to_f == 0

    # Buyer and Seller Totals
    # Sets no_payment to true so any payments are deleted if we are to receive money from entity instead of disburse
    return 0 if (self.number == 603 && self.seller_amount.to_f < 0)

    amount = self.number < 3000 ?  self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f + self.endorsement_amount.to_f : self.amount.to_f + self.charges.to_f - self.credits.to_f
    file = self.hud.index

    # TODO: I think that I changed some of this stuff in marks_branch, specifically the stuff with 1201 and 1202. We'll need to pull in those changes to be sure.
    # Borrower proceeds are stored as a negative amount so we need to correct (303)
    # Proceeds are on the charges (3097, 4097)
    # Deposits/Earnest Moneies are already paid and need to be a negative against disbursement (704)
    # Don't include the borrowers closing costs, those are handled on 1101 (1102)
    # If loan type, include reconveyance fee. Otherwise exclude 1202 (1201)
    # Only return the release amount (1202)
    case self.number
    when 303
      return 0 if -1 * amount < 0
    when 5099
      return 0 if self.credits.to_f - self.charges.to_f < 0
    when 3097, 4097
      return self.charges.to_f
    when 704
      return -amount if self.poc.to_s != ""
    when 1102
      return self.seller_amount.to_f
    when 1201
      return self.hud.hud_lines.where(number: 1202).sum{|l| l.deed_amount.to_f + l.mortgage_amount.to_f + l.releases_amount.to_f } if file.TransactionDescription1 == "Refinance" || file.TransactionDescription1 == "Construction Loan"
      return self.hud.hud_lines.where(number: 1202).sum{|l| l.deed_amount.to_f + l.mortgage_amount.to_f }
    when 1202
      return self.releases_amount.to_f
    end

    return self.borrower_amount.to_f + self.seller_amount.to_f if self.payee_id == self.company_id && self.number > 1103 && self.number < 1200
    return amount
  end

  def company_id ; return self.hud.index.Company ; end

  # This method is for the benefit of payment_disbursement.rb
  def get(attribute)
    return self.send(attribute)
  end

  def update_payment
    if self.poc_changed?
      if !self.poc.blank? && self.poc_was.blank?
        self.payment_disbursements.each do |payment_disbursement|
          payment_disbursement.update_attributes(funds_type: "poc")
        end
      elsif self.poc.blank?
        self.payment_disbursements.each do |payment_disbursement|
          payment_disbursement.update_attributes(funds_type: "check")
        end
      end
    end
  end

  def create_payment
    hud = Hud.find(self.hud_id)
    file = hud.index
    return if file == nil || file.SentForFunding != nil

    do_not_disburse = [703, 801, 901, 902, 903, 3096, 3099, 4096, 4099, 5096]
    hud.hud_lines.where("type LIKE 'ss_commission_total%' ").each do |line|
      do_not_disburse << line.number
    end

    return if do_not_disburse.include?(self.number)

    # Collect all of the information neccessary for the new payment disbursement model
    cell = Hash.new
    if self.payee_name_changed?
      cell["cell_name"] = "payee_name"
      cell["cell_value_changed?"] = true
      cell["cell_value_was"] = self.payee_name
    elsif self.amount_changed?
      cell["cell_name"] = "amount"
      cell["cell_value_changed?"] = true
      cell["cell_value_was"] = self.amount
    elsif self.endorsement_amount_changed?
      cell["cell_name"] = "endorsement_amount"
      cell["cell_value_changed?"] = true
      cell["cell_value_was"] = self.endorsement_amount
    elsif self.borrower_amount_changed?
      cell["cell_name"] = "borrower_amount"
      cell["cell_value_changed?"] = true
      cell["cell_value_was"] = self.borrower_amount
    elsif self.seller_amount_changed?
      cell["cell_name"] = "seller_amount"
      cell["cell_value_changed?"] = true
      cell["cell_value_was"] = self.seller_amount
    end

    PaymentDisbursement.handle(self, cell) if cell.size > 0

    # hud = Hud.find(self.hud_id)
    # file = Index.where("FileID = #{hud.file_id}").first
    # return if file.SentForFunding != nil

    # company_id = file.Company
    # no_payment = false
    # amount = 0

    # do_not_disburse = [
    #   703, 801, 901, 902, 903,
    #   3096, 3099, 4096, 4099, 5096
    # ]

    # hud.hud_lines.where("type LIKE 'ss_commission_total%' ").each do |line|
    #   do_not_disburse << line.number
    # end

    # return if do_not_disburse.include?(self.number) || file == nil
    # return if (self.number > 1300 && self.number < 1400 && self.borrower_amount.to_f <= 0 && self.seller_amount.to_f <= 0 && self.hud_line_payments.first == nil)
    # return if (self.number > 800 && self.number < 900 && self.borrower_amount.to_f <= 0 && self.seller_amount.to_f <= 0 && self.hud_line_payments.first == nil)
    # return if self.payee_id == company_id && self.number > 1103 && self.number < 1200 && self.borrower_amount.to_f == 0 && self.seller_amount.to_f == 0

    # # Destroy the payment and check if they no longer relate
    # payment = self.hud_line_payments.first
    # check = payment.check_working rescue nil

    # return if check != nil && (check.check_id != nil || check.check_number != nil)

    # if payment != nil && payment.check_working != nil && (self.payee_id != payment.entity_id || (self.payee_id == nil && self.payee_name != payment.check_working.payee_1) )
    #   check = payment.check_working
    #   payment.destroy

    #   if check.hud_line_payments.size <= 1
    #     check.destroy
    #   end
    # end

    # self.number < 3000 ? amount = self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f + self.endorsement_amount.to_f : amount = self.amount.to_f + self.charges.to_f - self.credits.to_f

    # # Sets amount to zero so payment is deleted if payment is to lender within 800 Section
    # no_payment = true if self.number > 800 && self.number < 900 && self.payee_id == hud.hud_lines.where("number = 801").first.payee_id && hud.hud_lines.where("number = 801").first.payee_id != nil

    # # Sets amount to zero if tax status is not debit
    # no_payment = true if hud.tax_status != "debit" && [107, 207, 407, 511].include?(self.number)

    # # No payment if to company or in 500 section
    # no_payment = true if (self.name == 'Earnest Money' || self.name == 'Down Payment') && (self.payee_id == company_id || self.number < 700)

    # # Buyer and Seller Totals
    # # Sets no_payment to true so any payments are deleted if we are to receive money from entity instead of disburse
    # if (self.number == 603 && self.seller_amount.to_f < 0)
    #   no_payment = true
    # elsif [603].include?(self.number)
    #   description = "Seller Proceeds"
    # end

    # case self.number
    # when 303
    #   amount = -1 * amount
    #   if amount < 0
    #     no_payment = true
    #   end
    #   description = "Buyer Proceeds"
    # when 5099
    #   amount = self.credits.to_f - self.charges.to_f
    #   if amount < 0
    #     no_payment = true
    #   end
    #   description = "Borrower Proceeds"
    # when 3097
    #   amount = self.charges.to_f
    #   if amount == 0
    #     no_payment = true
    #   end
    #   description = "Buyer Proceeds"
    # when 4097
    #   amount = self.charges.to_f
    #   if amount == 0
    #     no_payment = true
    #   end
    #   description = "Seller Proceeds"
    # when 704
    #   if self.poc.to_s != ""
    #     amount = -amount
    #   end
    # when 1102
    #   amount = self.seller_amount
    # when 1201
    #   if file.TransactionDescription1 == "Refinance" || file.TransactionDescription1 == "Construction Loan"
    #     amount = self.hud.hud_lines.where(number: 1202).sum{|l| l.deed_amount.to_f + l.mortgage_amount.to_f + l.releases_amount.to_f }
    #   else
    #     amount = self.hud.hud_lines.where(number: 1202).sum{|l| l.deed_amount.to_f + l.mortgage_amount.to_f }
    #   end
    # when 1202
    #   amount = self.releases_amount
    # end

    # if self.payee_id == company_id && self.number > 1103 && self.number < 1200
    #   amount = self.borrower_amount.to_f + self.seller_amount.to_f
    # end

    # # Check to see if line is able to create payment or delete any existing payments if it is not
    # if amount.to_f != 0 && self.payee_name.to_s != "" && (self.poc == nil || self.poc == "" || self.number == 704 || self.number == 4001) && !no_payment
    #   if ([701, 702].include?(self.number) || self.type.to_s.include?("ss_commission") && !self.type.include?("ss_commission_total")) && file.FileID != nil && self.payee_id != nil
    #     property = file.file_doc_fields.where("tag = 'PROPERTY_ADDRESS' AND doc_id = 0 AND is_active = 1").first.value rescue ""
    #     broker = FileEntity.where("FileID = #{file.FileID} AND EntityID = #{self.payee_id}").first

    #     if broker != nil
    #       case broker.Position
    #       when 12
    #         position = 4
    #       when 13
    #         position = 5
    #       when 14
    #         position = 6
    #       end
    #       agent = FileEntity.where("FileID = #{file.FileID} AND Position = #{position}").first if position != nil
    #     end

    #     agent != nil ? description = "Agent: #{agent.entity.name} / Property: #{property}" : description = "Property: #{property}"
    #   else
    #     description = self.name if description == nil
    #     if description.to_s.strip[-3..-1] == " to"
    #       description = description.to_s.strip[0...-3]
    #     end
    #   end

    #   payments = HudLinePayment.where("hud_line_id = #{self.id}")
    #   case payments.count
    #   when 0
    #     payment             = HudLinePayment.new
    #     payment.hud_id      = self.hud_id
    #     payment.hud_line_id = self.id
    #     payment.company_id  = company_id
    #     new_payment = true
    #   when 1
    #     payment = payments.first
    #     check = payment.check_working

    #     unless check.blank?
    #       if check.payee_1_id == file.Company
    #         if check.purpose_value.blank? && check.purpose != "FILE"
    #           check.purpose = "INVOICE"
    #           check.purpose_value = hud.invoice_id
    #           check.memo_1 = "Title Fees"
    #         end

    #         unless self.invoice_category.blank?
    #           payment.purpose = "INVOICE"
    #           payment.purpose_value = self.invoice_category
    #         end
    #       elsif check.purpose == nil
    #         payment.purpose = nil
    #         payment.purpose_value = nil
    #         check.purpose = payment.purpose
    #         check.purpose_value = payment.purpose_value
    #       end

    #       payment.amount = amount
    #       payment.memo_1 = description
    #       payment.save

    #       check.amount = CheckWorking.find(check.id).hud_line_payments.sum("amount")
    #       check.save
    #       return
    #     end
    #   else
    #     return
    #   end

    #   check = CheckWorking.find(payment.check_id) rescue nil
    #   check = CheckWorking.where("payee_1_id = #{self.payee_id} AND file_id = #{file.FileID}").first if check.blank? && self.payee_id
    #   check = CheckWorking.where("payee_1 = '#{self.payee_name.gsub(/[']/, "\\\'")}' AND file_id = #{file.FileID}").first if check.blank?

    #   if check == nil || (self.payee_id != check.payee_1_id && self.payee_id != nil && check.payee_1_id != nil)
    #     check = CheckWorking.new
    #     check.file_id    = file.FileID
    #     check.company_id = company_id
    #     if self.payee_id != company_id
    #       check.memo_1 = description
    #     end
    #     check.funds_type = "check"

    #     if !file.PrintCheckOffice.nil?
    #       check.print_office_id = file.PrintCheckOffice
    #     else
    #       check.print_office_id = hud.doc.update_employee.Office rescue nil
    #     end

    #     check.save
    #   end

    #   payment.check_id = check.id if new_payment || payment.check_id == nil

    #   if self.name.to_s.include?('Earnest Money') || self.name.to_s.include?('Down Payment')
    #     if self.number != 4001
    #       payment.amount = amount
    #       payment.memo_1 = self.name
    #     else
    #       # A) If the amount field is empty, then the down payment is going to the seller or borrower so delete the records and get out.
    #       # B) If the line number is 4001 then we assume that this has been taken care of on the buyer's side and therefore delete the payment.
    #       payment.save
    #       payment.destroy
    #       if CheckWorking.find(check.id).hud_line_payments.count == 0
    #         check.destroy
    #       end
    #       return
    #     end
    #   else
    #     payment.memo_1  = description
    #     payment.amount  = amount
    #   end

    #   payment.entity_id   = self.payee_id rescue nil
    #   payment.save

    #   if self.payee_id != check.payee_1_id || self.payee_id == nil # Check to see if we need to update the payee on the disbursement
    #     check.payee_1 = self.payee_name
    #     check.payee_1_id = self.payee_id

    #     if self.payee_id == company_id #BEGIN Disbursement Entity
    #       entity             = Company.find self.payee_id
    #       csz                = entity.CompanyCSZ
    #       a                  = csz.split(",")
    #       b                  = a[1].split(" ")
    #       check.address_1    = entity.CompanyAddress
    #       check.city         = a[0]
    #       check.state        = b[0]
    #       check.zip          = b[1]
    #     elsif self.payee_id != nil
    #       if check.funds_type.downcase == "check" #BEGIN Funds Type
    #         prev = CheckWorking.where("payee_1_id = #{self.payee_id} AND funds_type = 'check' AND id != #{check.id}").last
    #         if prev #BEGIN Previous Check Info
    #           address_1     = prev.address_1
    #           address_2     = prev.address_2
    #           city          = prev.city
    #           state         = prev.state
    #           zip           = prev.zip
    #         else
    #           entity            = Entity.find self.payee_id
    #           full_address      = entity.address_with_2
    #           address_1   = full_address[0] || nil
    #           address_2   = full_address[1] || nil
    #           city        = full_address[2] || nil
    #           state       = full_address[3] || nil
    #           zip         = full_address[4] || nil
    #         end #END Previous Check Info
    #       else
    #         prev = CheckWorking.where("payee_1_id = #{self.payee_id} AND funds_type = 'wire' AND id != #{check.id}").last
    #         if prev #BEGIN Previous Wire Info
    #           account_name    = prev.beneficiary_name
    #           account_number  = prev.beneficiary_account_number
    #           bank_name       = prev.beneficiary_bank_name
    #           bank_routing    = prev.beneficiary_bank_routing
    #         end #END Previous Wire Info
    #       end #END Funds Type

    #       check.address_1    = address_1
    #       check.address_2    = address_2
    #       check.city         = city
    #       check.state        = state
    #       check.zip          = zip

    #       check.beneficiary_name = account_name
    #       check.beneficiary_account_number = account_number
    #       check.beneficiary_bank_name = bank_name
    #       check.beneficiary_bank_routing = bank_routing
    #     end #END Disbursement Entity
    #   end

    #   if check.payee_1_id == file.Company
    #     if check.purpose_value.blank? && check.purpose != "FILE"
    #       check.purpose = "INVOICE"
    #       check.purpose_value = hud.invoice_id
    #       check.memo_1 = "Title Fees"
    #     end

    #     if self.invoice_category != nil
    #       payment.purpose = "INVOICE"
    #       payment.purpose_value = self.invoice_category
    #     end
    #   elsif check.purpose == nil
    #     payment.purpose = nil
    #     payment.purpose_value = nil
    #     check.purpose = payment.purpose
    #     check.purpose_value = payment.purpose_value
    #   end

    #   check.amount = HudLinePayment.where("check_id = #{check.id}").sum("amount").to_f
    #   if check.amount == 0
    #     payment.destroy
    #     check.destroy
    #   else
    #     payment.save
    #     check.save
    #   end
    # else
    #   #Delete Any Payments associated with this line
    #   payment = self.hud_line_payments.first

    #   if payment
    #     check_id = payment.check_id
    #     payment.destroy
    #     check            = CheckWorking.find(check_id) rescue nil
    #     if check && check.hud_line_payments.count == 0
    #       check.destroy
    #     end
    #   end
    # end
  end

  #
  # Math for HUD
  #
  ## Section J. Summary of Borrower's Transaction
  def self.line_103
    line_1400_borrower
  end

  def self.line_120
    self.where(:number => 101..119).sum('borrower_amount').to_f
  end

  def self.line_202

  end

  def self.line_220
    self.where(:number => 201..219).sum('borrower_amount').to_f
  end

  def self.line_301
    line = self.where(:number => 301).first
    if line.group == "custom"
      line.borrower_amount.to_f
    else
      self.where(:number => 120).first.borrower_amount.to_f
    end
  end

  def self.line_302
    line = self.where(:number => 220).first
    if line.group == "custom"
      line.borrower_amount.to_f
    else
      self.where(:number => 220).first.borrower_amount.to_f
    end
  end

  def self.line_303
    line_301 - line_302
  end

  ## Section K. Summary of Seller's Transaction
  def self.line_420
    self.where(:number => 401..419).sum('seller_amount').to_f
  end

  def self.line_502
    line_1400_seller
  end

  def self.line_506
    self.where(:number => 201).first.seller_amount.to_f
  end

  def self.line_520
    self.where(:number => 501..519).sum('seller_amount').to_f
  end

  def self.line_601
    line = self.where(:number => 601).first
    if line.group == "custom"
      line.seller_amount.to_f
    else
      self.where(:number => 420).first.seller_amount.to_f
    end
  end

  def self.line_602
    line = self.where(:number => 602).first
    if line.group == "custom"
      line.seller_amount.to_f
    else
      self.where(:number => 520).first.seller_amount.to_f
    end
  end

  def self.line_603
    line_601 - line_602
  end

  ## Section L. Settlement Charges
  def self.line_703
    line_704 = self.where("number = 704").first
    hud = Hud.find line_704.hud_id
    file = Index.where("FileID = #{hud.file_id}").first

    if line_704.payee_id != file.Company && line_704.poc.to_s != ""
      return self.where(:number => [701,702]).sum("amount").to_f - line_704.amount.to_f
    else
      return self.where(:number => [701,702]).sum("amount").to_f
    end
  end

  def self.line_801
    self.where("number = 800 OR (number > 803 AND number < 900 AND description = '(from GFE #1)')").sum("amount").to_f
  end

  def self.line_803
    self.where("number IN (801, 802)").sum("amount").to_f
  end

  def self.line_901(start_date, end_date, daily_interest)
    days = end_date.mjd - start_date.mjd
    return days * daily_interest
  end

  def self.line_1001
    self.where(:number => 1002..1006).sum('amount').to_f - self.where(:number => 1007).sum('amount').to_f
  end

  def self.line_1101
    self.where("number > 1101 AND 1200 > number AND number NOT IN (1105, 1106) AND (poc = '' OR poc IS NULL) AND payee_id = #{Hud.find(self.first.hud_id).hud_lines.where('number = 1102').first.payee_id}").sum{|l| l.amount.to_f + l.endorsement_amount.to_f}.to_f
  end

  def self.line_1103
    self.where(:number => [1103]).first.borrower_amount.to_f
  end

  def self.line_1201
    file = self.first.hud.index
    if file.TransactionDescription1 == "Refinance" || file.TransactionDescription1 == "Construction Loan"
      self.where(number: 1202).sum{|l| l.deed_amount.to_f + l.mortgage_amount.to_f + l.releases_amount.to_f }
    else
      self.where(number: 1202).sum{|l| l.deed_amount.to_f + l.mortgage_amount.to_f }
    end
  end

  def self.line_1202
    self.where(:number => 1202).sum('releases_amount').to_f
  end

  def self.line_1203
    self.where(:number => 1204).sum('deed_amount').to_f + self.where(:number => 1204).sum('mortgage_amount').to_f + self.where(:number => 1205).sum('deed_amount').to_f + self.where(:number => 1205).sum('mortgage_amount').to_f
  end

  def self.line_1301
    self.where("number > 1301 AND number < 1400").sum("amount").to_f
  end

  def self.line_1400_borrower
    total = []
    self.where(:number => [703..799,801..899,901..999,1001..1099,1101..1199,1201..1299,1301..1399]).sum('borrower_amount').to_f
  end

  def self.line_1400_seller
    self.where(:number => [703..799,801..899,901..999,1001..1099,1101..1199,1201..1299,1301..1399]).sum('seller_amount').to_f
  end

  def self.gfe_total
    self.where(:number => [2100..2199]).sum('gfe_amount').to_f
  end

  def self.hud_total
    self.where(:number => [2100..2199]).sum('hud_amount').to_f
  end

  def self.buyer_charge_subtotal
    self.where(:number => [3000..3095]).sum('charges').to_f
  end

  def self.buyer_credit_subtotal
    self.where(:number => [3000..3095]).sum('credits').to_f
  end

  def self.buyer_charge_due
    a = buyer_charge_subtotal
    b = buyer_credit_subtotal
    a > b ? c = a - b : c = 0
    return c
  end

  def self.buyer_credit_due
    a = buyer_charge_subtotal
    b = buyer_credit_subtotal
    b > a ? c = b - a : c = 0
    return c
  end

  def self.buyer_charge_total
    self.where(:number => [3096,3097]).sum('charges').to_f
  end

  def self.buyer_credit_total
    self.where(:number => [3096,3097]).sum('credits').to_f
  end

  def self.seller_charge_subtotal
    self.where(:number => [4000..4095]).sum('charges').to_f
  end

  def self.seller_credit_subtotal
    self.where(:number => [4000..4095]).sum('credits').to_f
  end

  def self.seller_charge_due
    a = seller_charge_subtotal
    b = seller_credit_subtotal
    a > b ? c = a - b : c = 0
    return c
  end

  def self.seller_credit_due
    a = seller_charge_subtotal
    b = seller_credit_subtotal
    b > a ? c = b - a : c = 0
    return c
  end

  def self.seller_charge_total
    self.where(:number => [4096,4097]).sum('charges').to_f
  end

  def self.seller_credit_total
    self.where(:number => [4096,4097]).sum('credits').to_f
  end

  def self.loan_charge_subtotal
    self.where(:number => [5000..5095]).sum('charges').to_f
  end

  def self.loan_credit_subtotal
    self.where(:number => [5000..5095]).sum('credits').to_f
  end

  def self.loan_charge_total
    self.where(:number => [5096,5097]).sum('charges').to_f
  end

  def self.loan_credit_total
    self.where(:number => [5096,5097]).sum('credits').to_f
  end

  def self.loan_charge_due
    a = loan_charge_subtotal
    b = loan_credit_subtotal
    a > b ? c = a - b : c = 0
  end

  def self.loan_credit_due
    a = loan_charge_subtotal
    b = loan_credit_subtotal
    b > a ? c = b - a : c = 0
  end

  def self.buyers_tax_proration(line_1,line_2)
    date           = self.where(:number => line_1).first
    amount         = self.where(:number => line_2).first
    length         = (date.end_date.mjd - date.start_date.mjd)
    total_length   = amount.periods
    amount.description != nil ? amount_desc = amount.description.downcase : amount_desc = ""
    if amount_desc == "days" || amount_desc == "day"
      length_divided = total_length.to_f != 0 ? length/total_length.to_f : 0
    elsif amount_desc == "months" || amount_desc == "month"
      length_divided = total_length.to_f != 0 ? length/((total_length*30.4).round(0)).to_f : 0
      # length_divided = length/((total_length*30.4).round(0)).to_f
    end
    total = length_divided*amount.periodic_amount rescue 0.0
    total.round(2)
  end

  def self.sellers_tax_proration(line_1,line_2)
    date           = self.where(:number => line_1).first
    amount         = self.where(:number => line_2).first

    if amount.periods
      length         = (date.end_date.mjd - date.start_date.mjd)
      total_length   = amount.periods
      amount.description != nil ? amount_desc = amount.description.downcase : amount_desc = ""
      if amount_desc == "days" || amount_desc == "day"
        length_divided = total_length.to_f != 0 ? length/total_length.to_f : 0
        # length_divided = length/total_length.to_f
      elsif amount_desc == "months" || amount_desc == "month"
        length_divided = total_length.to_f != 0 ? length/((total_length*30.4).round(0)).to_f : 0
        # length_divided = length/((total_length*30.4).round(0)).to_f
      end
    end
    total = length_divided*amount.periodic_amount rescue 0.0
    return total.round(2) || 0.0
  end

  def self.loan_tax_proration(line_1,line2)
    date           = self.where(:number => line_1).first
    amount         = self.where(:number => line_2).first
    length         = date.end_date.mjd - date.start_date.mjd
    total_length   = amount.periods
    amount.description != nil ? amount_desc = amount.description.downcase : amount_desc = ""
    if amount_desc == "days" || amount_desc == "day"
      length_divided = total_length.to_f != 0 ? length/total_length.to_f : 0
      # length_divided = length/total_length.to_f
    elsif amount_desc == "months" || amount_desc == "month"
      length_divided = total_length.to_f != 0 ? length/((total_length*30.4).round(0)).to_f : 0
      # length_divided = length/((total_length*30.4).round(0)).to_f
    end
    total = length_divided*amount.periodic_amount
    total.round(2)
  end

  def self.buyers_commissions(lines)
    self.where(:number => [lines]).sum('amount').to_f
  end

  def self.sellers_commissions(lines)
    self.where(:number => [lines]).sum('amount').to_f
  end

  def self.loan_commissions(lines)
    self.where(:number => [lines]).sum('amount').to_f
  end

  def self.calculate_commission(sales_price,hud_type = "standard")
    if hud_type == "standard"
      line_701 = self.where(:number => 701).first
      if line_701.percent.nil? == false
        line_701.amount = sales_price*(line_701.percent/100)
        line_701.save
      end

      line_702 = self.where(:number => 702).first
      if line_702.percent.nil? == false
        line_702.amount = sales_price*(line_702.percent/100)
        line_702.save
      end
    end
  end
  ###

  def skip_calculations
    if @@skip_calculations == true
      @@skip_calculations = false
      return true
    end
    return false
  end

  def skip_create_payment
    if @@skip_create_payment == true
      @@skip_create_payment = false
      return true
    end
    return false
  end

  #
  # Calculate the HUD each time a line is updated to check if it affects any other lines
  #

  def calculate_hud_by_line
    case self.number
    ## Section J
    when 101..119
      case self.number
      when 101
        if @@run_once == true
          @@run_once = false
        else
          @@run_once = true
          hud = self.hud
          file = hud.index
          if file.SalesPrice.to_f != self.borrower_amount.to_f
            file.SalesPrice = self.borrower_amount.to_f
            file.save
          end
          update_line(401,"seller_amount",self.borrower_amount)
          update_line(1106, "amount", self.borrower_amount)
        end
      end
      value = Hud.find(self.hud_id).hud_lines.line_120
      update_line(120,"borrower_amount",value)
    when 120
      Hud.find(self.hud_id).hud_lines.line_120
      value = Hud.find(self.hud_id).hud_lines.line_301
      update_line(301,"borrower_amount",value)
    when 201,203..219
      value = Hud.find(self.hud_id).hud_lines.line_220
      update_line(220,"borrower_amount",value)
    when 202
      value = Hud.find(self.hud_id).hud_lines.line_220
      update_line(220,"borrower_amount",value)
      if @@run_once == true
        @@run_once = false
      else
        @@run_once = true
      end

      hud = self.hud
      file = hud.index
      if hud.initial_loan_amount != self.borrower_amount
        hud.initial_loan_amount = self.borrower_amount
        hud.save
      end
      if file.LoanAmount.to_f != self.borrower_amount.to_f
        file.LoanAmount = self.borrower_amount.to_f
        file.save
      end

      other = hud.hud_lines.where("number = 1105").first
      if other.amount != self.borrower_amount
        update_line(1105, "amount", self.borrower_amount)
      end
    when 220
      value = Hud.find(self.hud_id).hud_lines.line_302
      update_line(302,"borrower_amount",value)
    when 301..302
      value = Hud.find(self.hud_id).hud_lines.line_303
      update_line(303,"borrower_amount",value)

    # Section K
    when 401..419
      case self.number
      when 401
        if @@run_once == true
          @@run_once = false
        else
          @@run_once = true
          hud = self.hud
          file = hud.index
          if file.SalesPrice.to_f != self.seller_amount.to_f
            file.SalesPrice = self.seller_amount.to_f
            file.save
          end
          update_line(101,"borrower_amount",self.seller_amount)
          update_line(1106, "amount", self.seller_amount)
        end
      end
      value = Hud.find(self.hud_id).hud_lines.line_420
      update_line(420,"seller_amount",value)
    when 420
      value = Hud.find(self.hud_id).hud_lines.line_601
      update_line(601,"seller_amount",value)
    when 501..519
      value = Hud.find(self.hud_id).hud_lines.line_520
      update_line(520,"seller_amount",value)
    when 520
      value = Hud.find(self.hud_id).hud_lines.line_602
      update_line(602,"seller_amount",value)
    when 601..602
      value = Hud.find(self.hud_id).hud_lines.line_603
      update_line(603,"seller_amount",value)

    # Section L
    when 700
      if !self.amount.nil?
        Hud.find(self.hud_id).hud_lines.calculate_commission(self.amount)
      else
        @@skip_calculations = true
        file = Hud.find(self.hud_id).doc.index rescue nil
        if file
          update_line(700,"amount",file.SalesPrice || 0)
          Hud.find(self.hud_id).hud_lines.calculate_commission(file.SalesPrice || 0)
        end
      end
    when 701..702
      # Calculate sales commission based on percent
      if self.percent_changed? == true
        @@skip_calculations = true
        sales_price = Hud.find(self.hud_id).hud_lines.where(:number => 700).first.amount
        value = sales_price.to_f*(self.percent.to_f/100)
        update_line(self.number,"amount",value)
        self.amount = value

        value = Hud.find(self.hud_id).hud_lines.line_703
        update_line(703,"seller_amount",value)
      else
        value = Hud.find(self.hud_id).hud_lines.line_703
        update_line(703,"seller_amount",value)
      end
    when 704
      value = Hud.find(self.hud_id).hud_lines.line_703
      update_line(703,"seller_amount",value)
    when 703..899,901..999,1001..1099,1101..1199,1201..1299,1301..1399
      case self.number
      when 800
        value = Hud.find(self.hud_id).hud_lines.line_801
        update_line(801, "amount", value)
      when 801
        value = Hud.find(self.hud_id).hud_lines.line_803
        update_line(803,"borrower_amount",value)
        update_line(2000,"hud_amount",self.amount)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 802
        value = Hud.find(self.hud_id).hud_lines.line_803
        update_line(803,"borrower_amount",value)
        update_line(2001,"hud_amount",self.amount)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 803
        update_line(2002,"hud_amount",self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 804
        update_line(2101,"hud_amount",self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 805
        update_line(2102,"hud_amount",self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 806
        update_line(2103,"hud_amount",self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 807
        update_line(2104,"hud_amount",self.amount.to_f + self.borrower_amount.to_f + self.seller_amount.to_f)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 808..900
        value = Hud.find(self.hud_id).hud_lines.line_801
        update_line(801, "amount", value)
        gfe_line = self.hud.hud_lines.where("description = '#{self.number}'").first
        if gfe_line != nil
          gfe_line.name = self.name
          gfe_line.hud_amount = self.borrower_amount
          gfe_line.save
        end
      when 901
        @@skip_calculations = true
        if self.start_date_changed?
          # update_line(211,"start_date",self.start_date)
          # update_line(511,"start_date",self.start_date)
          if self.start_date != nil && self.start_date != ""
            date = self.start_date.to_s.split("-")
            date[1] = (date[1].to_i + 1).to_s
            # If the month spills over 12, reset it to 1 and increment to next year
            if date[1] == "13"
              date[1] = "01"
              date[0] = (date[0].to_i + 1).to_s
            end
            date[2] = "01"
            date = date.join("-")
            if self.end_date != date
              self.end_date = date
              update_line(901,"end_date", date)
            end
          end
        end

        if self.start_date != nil && self.end_date != nil && self.daily_interest != nil
          value = Hud.find(self.hud_id).hud_lines.line_901(self.start_date, self.end_date, self.daily_interest)
        else
          value = nil
        end
        update_line(901,"borrower_amount",value)
        value = Hud.find(self.hud_id).hud_lines.where(:number => 901).first.borrower_amount
        update_line(2201,"hud_amount",value)
        value = Hud.find(self.hud_id).hud_lines.where(:number => 901).first.daily_interest
        update_line(2201,"daily_interest",value)
      when 902
        update_line(2105,"hud_amount",self.borrower_amount)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 903
        update_line(2202,"hud_amount",self.borrower_amount)
      when 1001
        update_line(2200,"hud_amount",self.borrower_amount)
      when 1002..1006
        @@skip_calculations = true
        if self.periods != nil && self.periodic_amount != nil
          value = self.periods * self.periodic_amount
        else
          value = nil
        end
        update_line(self.number,"amount",value)

        total = Hud.find(self.hud_id).hud_lines.line_1001
        update_line(1001,"borrower_amount",total)
      when 1007
        update_line(1001,"borrower_amount",Hud.find(self.hud_id).hud_lines.line_1001)

      when 1101
        update_line(2106,"hud_amount",self.borrower_amount)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)

      when 1102
        update_line(1101,"borrower_amount",Hud.find(self.hud_id).hud_lines.line_1101)

      when 1103
        hud = Hud.find(self.hud_id)
        if self.borrower_amount_changed? == true
          n = 206
          a_line = false
          b_line = false
          while a_line == false && b_line == false do
            a = hud.line_by_number_or_default(n)
            @a_group = a.group
            b = hud.line_by_number_or_default(n+300)
            if a.group.to_s.end_with?("_custom")
              a_line = true
            else
              if a.name == nil && a.borrower_amount == nil && b.group != "line_1103"
                a_line = true
                a.name = "Credit - Owner's Title Insurance (Line 1103)"
                a.type = "jk_normal_custom"
                a.group = "line_1103"
                a.borrower_amount = self.borrower_amount
              else
                if a.group == "line_1103"
                  a_line = true
                  a.borrower_amount = self.borrower_amount
                end
              end
            end

            if b.group.to_s.end_with?("_custom")
              b_line = true
            else
              if b.name == nil && b.seller_amount == nil && @a_group != "line_1103"
                b_line = true
                b.name = "Owner's Title Insurance"
                b.type = "jk_normal_custom"
                b.group = "line_1103"
                b.seller_amount = self.borrower_amount
              else
                if b.group == "line_1103"
                  b_line = true
                  b.seller_amount = self.borrower_amount
                end
              end
            end

            if a_line == true && b.number - 300 == a.number
              a.save
            end
            if b_line == true && a.number + 300 == b.number
              b.save
            end
            n += 1
          end

          total_policy = Hud.find(self.hud_id).hud_lines.where("number IN (1103, 1104) AND payee_id = #{self.hud.index.Company}").sum{|l| l.amount.to_f + l.borrower_amount.to_f + l.seller_amount.to_f}.to_f
          agent_percentage = 0.88
          update_line(1107, "amount", total_policy * agent_percentage)
          update_line(1108, "amount", total_policy * (1 - agent_percentage))

          update_line(2107,"hud_amount",self.borrower_amount)
          update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
        end

        file = hud.index
        seller_line = hud.hud_lines.where("number = 603").first
        entity = file.file_doc_entities.where("tag = 'GRANTOR' AND doc_id = 0").first

        if self.payee_id != file.Company && self.payee_name != seller_line.payee_name
          seller_line.payee_id = self.payee_id
          seller_line.payee_name = self.payee_name
          seller_line.save
        elsif self.payee_id == file.Company
          if entity != nil && seller_line.payee_id != entity.entity_id
            seller_line.payee_id = entity.entity_id
          else
            seller_line.payee_id = nil
          end

          seller_line.payee_name = file.file_doc_fields.where("tag = 'GRANTOR_NAMES' AND doc_id = 0").first.value
          seller_line.save
        end
      when 1104
        hud = Hud.find(self.hud_id)
        file = hud.index
        value = hud.hud_lines.line_1101
        update_line(1101,"borrower_amount",value)

        borrower_line = hud.hud_lines.where("number = 303").first
        entity = file.file_doc_entities.where("tag = 'GRANTEE' AND doc_id = 0").first

        if self.payee_id != file.Company && self.payee_name != borrower_line.payee_name
          borrower_line.payee_id = self.payee_id
          borrower_line.payee_name = self.payee_name
          borrower_line.save
        elsif self.payee_id == file.Company
          if entity != nil && borrower_line.payee_id != entity.entity_id
            borrower_line.payee_id = entity.entity_id
          else
            borrower_line.payee_id = nil
          end

          borrower_line.payee_name = file.file_doc_fields.where("tag = 'GRANTEE_NAMES' AND doc_id = 0").first.value
          borrower_line.save
        end

        total_policy = Hud.find(self.hud_id).hud_lines.where("number IN (1103, 1104) AND payee_id = #{self.hud.index.Company}").sum{|l| l.amount.to_f + l.borrower_amount.to_f + l.seller_amount.to_f}.to_f
        agent_percentage = 0.88
        update_line(1107, "amount", total_policy * agent_percentage)
        update_line(1108, "amount", total_policy * (1 - agent_percentage))
      when 1109..1199
        hud = Hud.find(self.hud_id)
        value = hud.hud_lines.line_1101
        update_line(1101,"borrower_amount",value)

      when 1201
        update_line(2100,"hud_amount",self.borrower_amount)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)

      when 1202
        file = self.hud.index
        if file.TransactionDescription1 == "Refinance" || file.TransactionDescription1 == "Construction Loan"
          update_line(1201,"borrower_amount",Hud.find(self.hud_id).hud_lines.line_1201)
        else
          if self.releases_amount_changed? == true
            @@skip_calculations = true
            update_line(1202,"seller_amount",Hud.find(self.hud_id).hud_lines.line_1202)
          else
            update_line(1201,"borrower_amount",Hud.find(self.hud_id).hud_lines.line_1201)
          end
        end

      when 1203
        update_line(2003,"hud_amount",self.borrower_amount)
        update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)
      when 1204,1205
        update_line(1203,"borrower_amount",Hud.find(self.hud_id).hud_lines.line_1203)
      when 1302...1399
        value = HudLine.where("hud_id=#{self.hud_id} AND number > 1301 AND number < 1400").sum("amount")
        update_line(1301, "borrower_amount", value)
      end

      value = Hud.find(self.hud_id).hud_lines.line_1400_borrower
      update_line(1400,"borrower_amount",value)

      value = Hud.find(self.hud_id).hud_lines.line_1400_seller
      update_line(1400,"seller_amount",value)

    # Line 1400
    when 1400
      value = Hud.find(self.hud_id).hud_lines.line_1400_borrower
      update_line(103,"borrower_amount",value)

      value = Hud.find(self.hud_id).hud_lines.line_1400_seller
      update_line(502,"seller_amount",value)

    # Comparison Section
    when 2100..2199
      update_line("hud","gfe_total",Hud.find(self.hud_id).hud_lines.gfe_total)
      update_line("hud","hud_total",Hud.find(self.hud_id).hud_lines.hud_total)

    when 3000..3095
      if self.name == "Trust Deed and Note with Sellers"
        if @@run_once == false
          @@run_once = true
          line = Hud.find(self.hud_id).hud_lines.where(name: "Trust Deed and Note with Buyers").first
          if line.nil?
            @@run_once = false
          else
            update_line(line.number, "charges", self.credits)
          end
        else
          @@run_once = false
        end
      end

      case self.number
      when 3000
        if @@run_once == true
          @@run_once = false
        else
          @@run_once = true
          update_line(4000,"credits",self.charges)
        end
        calculate_line_by_type
      else
        calculate_line_by_type
      end
      value = Hud.find(self.hud_id).hud_lines.buyer_charge_subtotal
      update_line(3096,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.buyer_credit_subtotal
      update_line(3096,"credits",value)

    when 3096
      value = Hud.find(self.hud_id).hud_lines.buyer_credit_due
      value == 0 ? update_line(3097,"name","Balance Due From Buyer(s)") : update_line(3097,"name","Balance Due To Buyer(s)")
      update_line(3097,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.buyer_charge_due
      update_line(3097,"credits",value)

      value = Hud.find(self.hud_id).hud_lines.buyer_charge_total
      update_line(3099,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.buyer_credit_total
      update_line(3099,"credits",value)

    when 4000..4095
      calculate_line_by_type

      if self.name == "Trust Deed and Note with Buyers"
        if @@run_once == false
          @@run_once = true
          line = Hud.find(self.hud_id).hud_lines.where(name: "Trust Deed and Note with Sellers").first
          if line.nil?
            @@run_once = false
          else
            update_line(line.number, "charges", self.credits)
          end
        else
          @@run_once = false
        end
      end

      case self.number
      when 4012..4013
        # case self.group
        # when "ss_proration"
        #   @@skip_calculations = true
        #   case self.type.gsub('_custom','')
        #   when "ss_proration_date"
        #     proration_dates = Hud.find(self.hud_id).hud_lines.find(self.id)
        #     proration       = Hud.find(self.hud_id).hud_lines.where(:number => proration_dates.number + 1).first
        #   when "ss_proration"
        #     proration       = Hud.find(self.hud_id).hud_lines.find(self.id)
        #     proration_dates = Hud.find(self.hud_id).hud_lines.where(:number => proration.number - 1).first
        #   end
        #   if proration.periodic_amount != nil && proration_dates.start_date != nil && proration_dates.end_date != nil && proration_dates.name != "custom"
        #     value = Hud.find(self.hud_id).hud_lines.sellers_tax_proration(proration_dates.number,proration.number)
        #     update_line(proration.number,"charges",value)

        #     line_4012 = Hud.find(self.hud_id).hud_lines.where(:number => 4012).first
        #     line_4013 = Hud.find(self.hud_id).hud_lines.where(:number => 4013).first
        #     update_line(3013,"charges",line_4013.periodic_amount - value)
        #     update_line(3013,"periodic_amount",line_4013.periodic_amount)
        #     update_line(3013,"description",line_4013.description)
        #     update_line(3013,"periods",line_4013.periods)
        #     update_line(3012,"start_date",line_4012.end_date + 1)
        #     end_year = line_4012.end_date.to_datetime.strftime("%Y").to_i
        #     update_line(3012,"end_date",Date.new(end_year,12,31))
        #   elsif proration_dates.name != "custom"
        #     update_line(proration.number,"charges",0)
        #   end
        # end
      when 4000
        if @@run_once == true
          @@run_once = false
        else
          @@run_once = true
          update_line(3000,"charges",self.credits)
        end

        hud = Hud.find(self.hud_id)
        headers = hud.hud_lines.where("type LIKE 'ss_header%' AND name LIKE '%COMMISSION%' ")
        if headers.count > 0
          headers.each do |header|
            update_line(header.number, "amount", self.credits)
          end
        else
          commissions = hud.hud_lines.where("type LIKE 'ss_commission%' AND type NOT LIKE '%total%' ")
          commissions.each do |commission|
            update_line(commission.number, "amount", self.credits.to_f*(commission.percent.to_f/100))
          end
        end

        file = hud.index
        if file.SalesPrice.to_f != self.credits.to_f
          file.SalesPrice = self.credits.to_f
          file.save
        end

      when 4001
        update_line(3001,"credits",self.charges)
        update_line(3001,"credits",self.amount) if self.charges.nil? || self.charges == ""
        update_line(3001,"payee_name",self.payee_name) if self.payee_name
      end
      value = Hud.find(self.hud_id).hud_lines.seller_charge_subtotal
      update_line(4096,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.seller_credit_subtotal
      update_line(4096,"credits",value)

    when 4096
      value = Hud.find(self.hud_id).hud_lines.seller_credit_due
      value == 0 ? update_line(4097,"name","Balance Due From Seller(s)") : update_line(4097,"name","Balance Due To Seller(s)")
      update_line(4097,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.seller_charge_due
      update_line(4097,"credits",value)

      value = Hud.find(self.hud_id).hud_lines.seller_charge_total
      update_line(4099,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.seller_credit_total
      update_line(4099,"credits",value)

    when 5000..5095
      if self.number == 5000
        file = self.hud.index
        if file.LoanAmount.to_f != self.credits.to_f
          file.LoanAmount = self.credits.to_f
          file.save
        end
      end

      calculate_line_by_type
      value = Hud.find(self.hud_id).hud_lines.loan_charge_subtotal
      update_line(5096,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.loan_credit_subtotal
      update_line(5096,"credits",value)

    when 5096
      value = Hud.find(self.hud_id).hud_lines.loan_credit_due
      value == 0 ? update_line(5097,"name","Balance Due From Borrower(s)") : update_line(5097,"name","Balance Due To Borrower(s)")
      update_line(5097,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.loan_charge_due
      update_line(5097,"credits",value)

      value = Hud.find(self.hud_id).hud_lines.loan_charge_total
      update_line(5099,"charges",value)

      value = Hud.find(self.hud_id).hud_lines.loan_credit_total
      update_line(5099,"credits",value)
    end

    if self.number < 2000
      current = Hud.find(self.hud_id).hud_lines.where("number = #{self.number}").first
      Hud.find(self.hud_id).hud_lines.where("description = '#{self.number}' AND number >= 2000 AND number < 3000").each do |gfe_line|
        update_line(gfe_line.number,"hud_amount",current.borrower_amount.to_f + current.amount.to_f) if gfe_line.hud_amount.to_f != current.borrower_amount.to_f + current.amount.to_f
        update_line(gfe_line.number, "name", current.name) if gfe_line.name.to_s != current.name.to_s

        if current.number == 901
          update_line(gfe_line.number, "type", "m_periodic") if gfe_line.type != "m_periodic"
          update_line(gfe_line.number, "daily_interest", current.daily_interest)
        elsif gfe_line.type != "m_normal"
          update_line(gfe_line.number, "daily_interest", nil) unless gfe_line.daily_interest.blank?
          update_line(gfe_line.number, "type", "m_normal")
        end
      end
    end
  end

  def calculate_line_by_type
    case self.group
    when "ss_proration"
      @@skip_calculations = true
      unless [4012, 4013, 3012, 3013].include?(self.number)
        case self.type.gsub('_custom','')
        when "ss_proration_date"
          proration_dates = Hud.find(self.hud_id).hud_lines.find(self.id)
          proration       = Hud.find(self.hud_id).hud_lines.where(:number => proration_dates.number + 1).first
        when "ss_proration"
          proration       = Hud.find(self.hud_id).hud_lines.find(self.id)
          proration_dates = Hud.find(self.hud_id).hud_lines.where(:number => proration.number - 1).first
        end
        if proration.periodic_amount != nil && proration_dates.start_date != nil && proration_dates.end_date != nil && proration_dates.name != "custom"
          value = Hud.find(self.hud_id).hud_lines.sellers_tax_proration(proration_dates.number,proration.number)
          update_line(proration.number,"charges",value)
        else
          update_line(proration.number,"charges",0)
        end
      end
    when "ss_commission"
      hud = Hud.find(self.hud_id)
      line = hud.hud_lines.find(self.id)
      next_line = hud.hud_lines.where(:number => line.number + 1).first
      previous_line = hud.hud_lines.where(:number => line.number - 1).first
      lines = []

      if self.percent_changed? == true
        previous_commission_line = previous_line
        if previous_commission_line.type == "ss_header_custom"
          sales_price = previous_commission_line.amount
        else
          while previous_commission_line != nil && previous_commission_line.type != "ss_header_custom"
            previous_commission_line = hud.hud_lines.where(:number => previous_commission_line.number - 1).first
          end

          previous_commission_line != nil ? sales_price = previous_commission_line.amount : sales_price = hud.hud_lines.where("number = 4000").first.credits rescue nil
        end
        value = sales_price.to_f*(self.percent.to_f/100)
        update_line(self.number,"amount",value)
        self.amount = value
      end

      if self.type == "ss_header_custom"
        next_commission_line = next_line
        file_id = Index.where("FileID = #{hud.file_id}").first

        if self.amount == 0.00 && !file_id.SalesPrice.nil? || self.amount == 0.00 && file_id.SalesPrice != 0.00
          value       = file_id.SalesPrice
          self.amount = file_id.SalesPrice || 0.00
          update_line(self.number,"amount",value)
        elsif self.amount.nil?
          if next_commission_line.type == "ss_commission_custom"
            while next_commission_line.type == "ss_commission_custom"
              if next_commission_line.percent != nil
                update_line(next_commission_line.number,"amount",0.00)
              end
              next_commission_line = Hud.find(self.hud_id).hud_lines.where(:number => next_commission_line.number + 1).first
            end
          end
        elsif self.amount > 0
          if next_commission_line.type == "ss_commission_custom"
            while next_commission_line.type == "ss_commission_custom"
              if next_commission_line.percent != nil
                value = self.amount*(next_commission_line.percent/100)
                update_line(next_commission_line.number,"amount",value)
              end
              next_commission_line = Hud.find(self.hud_id).hud_lines.where(:number => next_commission_line.number + 1).first
            end
          end
        end
      end

      if self.amount != 0.00 || !self.amount.nil?
        if self.type == "ss_commission_total_custom" && self.amount == nil
          if previous_line.type == "ss_commission_custom"
            while previous_line.type == "ss_commission_custom" do
              lines << previous_line.number
              previous_line = Hud.find(self.hud_id).hud_lines.where(:number => previous_line.number - 1).first
            end
          end
          value = Hud.find(self.hud_id).hud_lines.buyers_commissions(lines)
          update_line(line.number,"amount",value)
          update_line(line.number,"charges",value)
          return
        elsif self.type == "ss_commission_total_custom" && self.amount.to_s > ""
          return
        end
        lines << line.number if line.type == "ss_commission_custom"
        if next_line.type == "ss_commission_custom"
          while next_line.type == "ss_commission_custom" do
            lines << next_line.number
            next_line = Hud.find(self.hud_id).hud_lines.where(:number => next_line.number + 1).first
            if next_line.type == "ss_commission_total_custom"
              commission_total_line = next_line.number
            end
          end
        elsif next_line.type == "ss_commission_total_custom"
          commission_total_line = next_line.number
        end
        if previous_line.type == "ss_commission_custom"
          while previous_line.type == "ss_commission_custom" do
            lines << previous_line.number
            previous_line = Hud.find(self.hud_id).hud_lines.where(:number => previous_line.number - 1).first
          end
        end
        if commission_total_line != nil
          value = Hud.find(self.hud_id).hud_lines.buyers_commissions(lines)
          update_line(commission_total_line,"amount",value)
          update_line(commission_total_line,"charges",value)
        end
      end
    end
  end

  def update_line(line_num,field,value)
    if line_num == "hud"
      case field
        when "initial_loan_amount"
          line = Hud.find(self.hud_id)
          line.initial_loan_amount = value
        when "gfe_total"
          line = Hud.find(self.hud_id)
          line.gfe_total = value
        when "hud_total"
          line = Hud.find(self.hud_id)
          line.hud_total = value
      end
    else
      line = Hud.find(self.hud_id).hud_lines.where(:number => line_num).first
      if line.group.to_s.end_with?("custom")
        #@line.save
        return
      else
        if line != nil
          line.send(field + "=", value)
          # case field
          # when "borrower_amount"
          #   @line.borrower_amount = value
          # when "seller_amount"
          #   @line.seller_amount = value
          # when "amount"
          #   @line.amount = value
          # when "hud_amount"
          #   @line.hud_amount = value
          # when "gfe_amount"
          #   @line.gfe_amount = value
          # when "mortgage_amount"
          #   @line.mortgage_amount = value
          # when "deed_amount"
          #   @line.deed_amount = value
          # when "releases_amount"
          #   @line.releases_amount = value
          # when "charges"
          #   @line.charges = value
          # when "credits"
          #   @line.credits = value
          # when "periodic_amount"
          #   @line.periodic_amount = value
          # when "periods"
          #   @line.periods = value
          # when "description"
          #   @line.description = value
          # when "start_date"
          #   @line.start_date = value
          # when "end_date"
          #   @line.end_date = value
          # end
        else
          return nil
        end
      end
    end
    line.save
  end
end
