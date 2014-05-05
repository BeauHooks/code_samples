class PaymentDisbursement < ActiveRecord::Base
  cattr_accessor :override # Generally set from the update function in the payment_disbursements controller

  after_create :assign_disbursement
  after_destroy :destroy_from_disbursement

  belongs_to :check_working
  belongs_to :ss_line
  belongs_to :hud_line

  default_scope {order("id ASC")}

  def update_attributes(attributes)
    disbursement_attributes = Hash.new
    attributes.each do |key, value|
      if self.attributes.include?(key.to_s)
        self.send(key.to_s + "=", value)
      else
        disbursement_attributes[key] = value
        attributes.delete(key)
      end
    end
    self.save

    # Create a disbursement if this doesn't have one and type is not POC or if user has specified to create a new disbursement
    self.create_disbursement if (self.funds_type != "poc" && self.check_working.blank?) || self.override == "create_new"

    return if self.check_working.blank?

    # If the fund type changes, updates it's current check_working or destroy it if it's poc
    if self.funds_type == "poc"
      current_id = self.check_working_id
      self.update_column("check_working_id", nil)
      current = CheckWorking.find current_id
      current.payment_disbursements.size == 0 ? current.destroy : current.update_amount
      return
    end

    if self.check_working.funds_type != self.funds_type
      self.check_working.payment_disbursements.size == 1 || self.override == "update_all" ? disbursement_attributes[:funds_type] = self.funds_type : self.create_disbursement
    end

    # If this is the only payment associated with this disbursement, simply update the name on the disbursement
    # Otherwise, let's update the disbursement amount minus the payment and then create a new disbursement
    if !self.check_working_id_changed? && self.payee_name != self.check_working.payee_1
      self.check_working.payment_disbursements.size == 1 || self.override == "update_all" ? disbursement_attributes[:payee_1] = self.payee_name : self.create_disbursement
    end

    # Update the disbursement.
    self.check_working.update_attributes(disbursement_attributes) if disbursement_attributes.size > 0
    self.check_working.update_amount
  end

  # Called from SsLine model. This method finds the associated payment OR creates a new one.
  # TODO: Replace the cell hash with the cell object when we stop supporting the legacy hud.
  def self.handle(sender, cell)
    payment_disbursements = sender.class.table_name == "ss_lines" ? self.where(ss_line_id: sender.id) : self.where(hud_line_id: sender.id)
    return if payment_disbursements.size > 1

    payee_name = sender.get("payee_name")
    amount = sender.payment_amount

    # Create a new payment, update the existing, or do nothing
    if payment_disbursements.size == 0 && !(amount == 0 || payee_name.blank?)
      sender.class.table_name == "ss_lines" ? self.create(payee_name: payee_name, ss_line_id: sender.id, amount: amount, funds_type: "check") : self.create(payee_name: payee_name, hud_line_id: sender.id, amount: amount, funds_type: "check")
    elsif payment_disbursements.size == 1
      payment = payment_disbursements[0]

      if amount == 0 || payee_name.blank?
        payment.destroy
        return
      end

      disbursement_condition = payment.check_working.blank? || (!payment.check_working.blank? && payment.check_working.payment_disbursements.size == 1)
      if (self.override == "update_all" || disbursement_condition) && cell["cell_name"] == "payee_name" && cell["cell_value_changed?"] && cell["cell_value_was"] == payment.payee_name
        payment.update_attributes(payee_name: payee_name)
      end

      if amount != payment.amount
        payment.update_attributes(amount: amount)
      end
    end
  end

  def assign_disbursement
    self.create_disbursement if self.check_working.blank?
  end

  def create_disbursement
    file = self.index

    unless self.check_working.blank?
      current = self.check_working
      self.update_column("check_working_id", nil)
      current.update_amount
    end

    # if self.override == "create_new" || self.payee_name.blank?
      # disbursement = CheckWorking.create(file_id: file.FileID, company_id: file.Company,  payee_1: self.payee_name, funds_type: self.funds_type || "check", hold_back: 0)
    # else
    #   disbursement = CheckWorking.find_or_create_by_file_id_and_payee_1_and_funds_type(file_id: file.FileID, company_id: file.Company,  payee_1: self.payee_name || self.line_payee_name, funds_type: self.funds_type || "check", hold_back: 0)
    # end

    if self.ss_line.line_sub_type == "downpayment"
      disbursement = CheckWorking.find_or_create_by_file_id_and_payee_1_and_funds_type(file_id: file.FileID, company_id: file.Company,  payee_1: self.payee_name || self.line_payee_name, funds_type: self.funds_type || "check", hold_back: 0)
    else
      disbursement = CheckWorking.create(file_id: file.FileID, company_id: file.Company,  payee_1: self.payee_name, funds_type: self.funds_type || "check", hold_back: 0)
    end

    self.update_column("check_working_id", disbursement.id)
    disbursement.update_amount
  end

  def destroy_from_disbursement
    return if self.check_working_id.blank?
    disbursement = CheckWorking.where("id = '#{self.check_working_id}'").first
    unless disbursement.blank?
      disbursement.payment_disbursements.size == 0 ? disbursement.destroy : disbursement.update_amount
    end
  end

  def index ; return  self.hud_line_id.blank? ? self.ss_line.ss_section.settlement_statement.index : self.hud_line.hud.index ; end
  def line_payee_name ; return self.hud_line_id.blank? ? self.ss_line.get("payee_name") : self.hud_line.payee_name ; end
  def line ; return self.hud_line_id.blank? ? self.ss_line : self.hud_line ; end
  def line_id ; return self.hud_line_id.blank? ? self.ss_line_id : self.hud_line_id ; end

  # Treating this as if it were the check_working. If POC, then just return what we can from payment_disbursements
  def payee_1; return self.check_working.blank? ? self.payee_name : self.check_working.payee_1; end
  def address_1; return self.check_working.blank? ? nil : self.check_working.address_1; end
  def address_2; return self.check_working.blank? ? nil : self.check_working.address_2; end
  def city; return self.check_working.blank? ? nil : self.check_working.city; end
  def state; return self.check_working.blank? ? nil : self.check_working.state; end
  def zip; return self.check_working.blank? ? nil : self.check_working.zip; end
  def memo_1; return self.check_working.blank? ? nil : self.check_working.memo_1; end
  def beneficiary_bank_name; return self.check_working.blank? ? nil : self.check_working.beneficiary_bank_name; end
  def beneficiary_bank_routing; return self.check_working.blank? ? nil : self.check_working.beneficiary_bank_routing; end
  def beneficiary_account_number; return self.check_working.blank? ? nil : self.check_working.beneficiary_account_number; end
  def b2b_information_message; return self.check_working.blank? ? nil : self.check_working.b2b_information_message; end
end