class CheckWorking < DisburseBase
  include ActionView::Helpers::NumberHelper
  self.table_name = "check_working"

  before_create :update_from_ftweb_flag
  after_destroy :destroy_payments

  has_many   :hud_line_payments,                         foreign_key: "check_id",  primary_key: "id", dependent: :destroy
  has_many   :hud_lines,    through: :hud_line_payments
  has_one    :print_office, class_name: "Office",        foreign_key: "ID",        primary_key: "print_office_id"
  has_one    :entity,       class_name: "Entity",        foreign_key: "EntityID",  primary_key: "payee_1_id"
  has_one    :address,      class_name: "EntityContact", foreign_key: "ContactID", primary_key: "address_id"
  belongs_to :index,        class_name: "Index",         foreign_key: "file_id",   primary_key: "FileID"
  has_one    :check,                                     foreign_key: "ID",        primary_key: "check_id"
  has_many :payment_disbursements

  def update_from_ftweb_flag
      self.from_ftweb = -1
  end

  def update_attributes(attributes)
    toggle = []
    toggle_fields = ["hold_back", "rules_checked"]
    attributes.each do |key, value|
      key = key.to_s
      unless toggle_fields.include?(key)
        self.send(key + "=", value) if self.attributes.include?(key)
      else
        toggle << key
      end
    end

    toggle.each do |key|
      value = self.send(key) == -1 ? 0 : -1
      self.send(key + "=", value)
    end

    if attributes.include?(:purpose)
      if self.purpose == "FILE"
        self.payee_1_id = self.index.Company
        self.payee_1 = self.index.company.CompanyName
        self.funds_type = "check"
        self.set_preferred_payment()
        self.memo_1 = "Transfer to File #{self.purpose_value}"
      else
        self.payee_1_id = nil
        self.payee_1    = nil
        self.purpose    = nil
        self.purpose_value = nil
        self.memo_1     = nil

        self.beneficiary_name = nil
        self.beneficiary_account_number = nil
        self.beneficiary_bank_name = nil
        self.beneficiary_bank_routing = nil

        self.address_1 = nil
        self.address_2 = nil
        self.city      = nil
        self.state     = nil
        self.zip       = nil
        self.check_deliver = nil
      end
    end

    if self.purpose_value_changed? && self.purpose == "FILE"
      self.memo_1 = "Transfer to File ##{self.purpose_value}"
    end

    if self.payee_1_id_changed? && self.payee_1_id.blank?
      self.payee_1 = nil
      self.beneficiary_name = nil
    elsif self.payee_1_id_changed?
      unless self.payee_1_id == self.index.Company
        self.payee_1 = Entity.find(self.payee_1_id).name
      else
        self.payee_1 = Company.find(self.payee_1_id).CompanyName
      end
    end

    self.set_address if attributes.include?(:address_id)
    self.update_column("beneficiary_name", self.payee_1)  if self.payee_1_changed?
    self.update_column("payee_1", self.beneficiary_name)  if self.beneficiary_name_changed? && self.funds_type == "wire"

    if self.funds_type_changed?
      if self.funds_type_was == "check"
        self.beneficiary_name = self.payee_1
        self.b2b_information_message = self.memo_1.to_s

        self.address_1 = nil
        self.address_2 = nil
        self.city = nil
        self.state = nil
        self.zip = nil
        self.memo_1 = nil
      elsif self.funds_type_was == "wire"
        self.beneficiary_bank_name = nil
        self.beneficiary_account_number = nil
        self.beneficiary_bank_routing = nil
        self.memo_1 = self.b2b_information_message.to_s
        self.b2b_information_message = nil
      end
      self.set_preferred_payment()
    end

    child_attributes = Hash.new
    child_attributes["payee_name"] = self.payee_1 if self.payee_1_changed?
    child_attributes["funds_type"] = self.funds_type if self.funds_type_changed?
    child_attributes.each do |key, value|
      self.payment_disbursements.each do |payment|
        payment.update_column(key, value) unless payment.send(key) == value
      end
    end

    self.save
  end

  def update_amount
    if self.payment_disbursements.size == 0
      self.destroy
      return
    end

    self.update_attributes(amount: self.payment_disbursements.sum("amount")) if self.amount != self.payment_disbursements.sum("amount")
  end

  def destroy_payments
    PaymentDisbursement.where("check_working_id = #{self.id}").each do |payment|
      payment.destroy
    end
  end

  def get_disbursement_warnings
    warnings = []
    warnings << "Payee name is 'BLANK'" if self.payee_1 == "BLANK"
    warnings << "Funds in the amount of #{number_to_currency(self.amount, unit: "$")} are marked to be held." if self.hold_back != 0 && self.hold_back != nil
    warnings << "Payee name exceeds maximum character count: #{self.payee_1.to_s.length} of 50 characters." if self.payee_1.to_s.length > 50
    warnings << "Payee 2 name exceeds maximum character count: #{self.payee_2.to_s.length} of 50 characters." if self.payee_2.to_s.length > 50
    warnings
  end

  def get_disbursement_errors
    errors = []
    errors << "Amount must be greater than zero." if self.amount.to_f <= 0
    errors << "Payee line is blank." if self.payee_1.to_s == ""

    entity = Entity.find(self.payee_1_id) rescue nil
    rules = entity != nil ? entity.get_rules("Add to Disbursement") : self.payee_1.to_s != "" ? Rule.check_name(self.payee_1, "Add to Disbursement") : []

    if rules.size > 0 && self.rules_checked.to_i == 0
      errors << "Rules have not been marked as Reviewed."
    end

    file = self.index
    if self.payee_1_id == file.Company
      errors << "Check is missing a purpose." if self.purpose == nil
    end

    if self.funds_type.to_s.downcase == "wire"
      errors << "No wire out images exist." if file.file_images.where("ImageType = 'wireout'").size == 0
      errors << "Wire amount must be greater than zero." if self.amount == nil || self.amount == "" || self.amount == 0
      errors << "Company ID is missing." if self.company_id == nil
      errors << "Bank name is blank." if self.beneficiary_bank_name.to_s == ""
      errors << "Account number is blank." if self.beneficiary_account_number.to_s == ""

      validation_errors = self.routing_number_errors
      validation_errors.each do |routing_number_error|
        errors << routing_number_error
      end
    end
    errors
  end

  def routing_number_errors
    number = self.beneficiary_bank_routing.to_s
    validation_errors = []

    validation_errors << "Routing number is blank." if number.length == 0
    validation_errors << "Routing number contains characters that are not numeric." if !number.is_numeric?
    validation_errors << "Routing number is greater than 9 digits." if number.length > 9
    validation_errors << "Routing number is less than 9 digits." if number.length < 9

    if validation_errors.size == 0
      valid = true
      prefix = number[0..1].to_i
      check = number[0].to_i * 3 + number[1].to_i * 7 + number[2].to_i * 1 + number[3].to_i * 3 + number[4].to_i * 7 + number[5].to_i * 1 + number[6].to_i * 3 + number[7].to_i * 7 + number[8].to_i * 1
      valid = false if ( !(prefix >= 1 && prefix <= 12) && !(prefix >= 21 && prefix <= 32) ) || check % 10 != 0
      validation_errors << "Routing number is invalid." if !valid
    end
    validation_errors
  end

  def set_preferred_payment
    file = self.index
    address_id = nil
    address_1    = nil
    address_2    = nil
    city         = nil
    state        = nil
    zip          = nil
    beneficiary_name = nil
    beneficiary_account_number = nil
    beneficiary_bank_name = nil
    beneficiary_bank_routing = nil

    if self.payee_1_id == file.Company
      company = file.company

      csz          = company.CompanyCSZ
      a            = csz.split(",")
      b            = a[1].split(" ")
      address_1    = company.CompanyAddress
      address_2    = nil
      city         = a[0]
      state        = b[0]
      zip          = b[1]
    else
      entity = Entity.find self.payee_1_id rescue nil
      prev = CheckWorking.where("payee_1_id = #{self.payee_1_id} AND funds_type = '#{self.funds_type}' AND id != #{self.id} AND check_id IS NOT NULL").last rescue nil
      if prev
        address_id   = prev.address_id
        address_1    = prev.address_1
        address_2    = prev.address_2
        city         = prev.city
        state        = prev.state
        zip          = prev.zip

        beneficiary_name = prev.beneficiary_name
        beneficiary_account_number = prev.beneficiary_account_number
        beneficiary_bank_name = prev.beneficiary_bank_name
        beneficiary_bank_routing = prev.beneficiary_bank_routing
      elsif entity
        address = entity.addresses.first
        unless address == nil
          address_id   = address.ContactID
          address_1    = address.Address
          address_2    = address.Address2
          city         = address.City
          state        = address.State
          zip          = address.Zip
        end

        beneficiary_name = entity.name
      else
        beneficiary_name = self.payee_1
      end
    end

    # self.beneficiary_name = beneficiary_name
    self.beneficiary_account_number = beneficiary_account_number
    self.beneficiary_bank_name = beneficiary_bank_name
    self.beneficiary_bank_routing = beneficiary_bank_routing

    self.address_id = address_id
    self.address_1 = address_1
    self.address_2 = address_2
    self.city      = city
    self.state     = state
    self.zip       = zip

    if self.funds_type.downcase == "wire"
      self.check_deliver = nil
      self.memo_1 = nil
    else
      self.beneficiary_name = nil
      self.b2b_information_message = nil
    end
  end

  def set_address
    self.beneficiary_name = nil
    self.beneficiary_account_number = nil
    self.beneficiary_bank_name = nil
    self.beneficiary_bank_routing = nil

    if self.address_id == nil
      self.address_1    = nil
      self.address_2    = nil
      self.city         = nil
      self.state        = nil
      self.zip          = nil
    else
      address = self.address
      self.address_1    = address.Address
      self.address_2    = address.Address2
      self.city         = address.City
      self.state        = address.State
      self.zip          = address.Zip
    end
  end

  def cleared?
    self.check != nil ? self.check.Cleared != 0 : false
  end

  def cleared_date
    self.check != nil && !self.check.ClearedDate.blank? ? self.check.ClearedDate.strftime("%m/%d/%y") : ""
  end

  def voided?
    self.check != nil && !self.check.voiddate.blank?
  end

  def void_date
    self.check != nil && !self.check.voiddate.blank? ? self.check.voiddate.strftime("%m/%d/%y") : ""
  end

  def issue_date
    self.check != nil && !self.check.IssueDate.blank? ? self.check.IssueDate.strftime("%m/%d/%y") : ""
  end

  def memo
    self.funds_type.downcase == "check" ? self.memo_1.to_s : self.b2b_information_message.to_s
  end
end
