class ScheduleA < ActiveRecord::Base
  include AtomicText

  after_save :update_related
  after_save :save_history

  belongs_to :index, primary_key: "FileID", foreign_key: "file_id"
  belongs_to :file_product
  belongs_to :underwriter, class_name: "Underwriter", foreign_key: "underwriter_id", primary_key: "ID"
  belongs_to :property_type, primary_key: "TypeID", foreign_key: "land_type_id"
  belongs_to :rate_version, primary_key: "id", foreign_key: "version_id"
  has_many   :policies, conditions: "policies.removed_at IS NULL"
  has_many   :policy_endorsements, through: :policies
  has_many   :file_product_histories, primary_key: :id, foreign_key: :record_id

  EXCLUDE_FIELDS = ["id", "file_id", "file_product_id", "fp_exception_id", "schedule_a_id", "vesting", "underwriter_id", "policy_id", "proposed_insured",
    "created_by", "updated_by", "created_at", "updated_at", "removed_by", "removed_at", "product_type", "product_type_id", "version_id"]

  def update_related
    if self.underwriter_id_changed?
      file = self.file_product.index
      unless file.Underwriter == self.underwriter_id
        file.Underwriter = self.underwriter_id
        file.save
      end
    end
  end

  def save_history
    self.changed.each do |key|
      unless EXCLUDE_FIELDS.include?(key) || self.send(key + "_was").blank?
        FileProductHistory.create_history(self, key)
      end
    end
  end

  def get_history(field, date)
    history = self.file_product_histories.where("field_name = '#{field}' AND updated_at < '#{date}'").first
    return !history.nil? ? history.new_value : nil
  end

  def update_attributes(attributes, current_user)
    attributes.each do |key, value|
      if !EXCLUDE_FIELDS.include?(key) && self.attributes.include?(key)
        self.send(key + "=", (value || nil))
      end
    end

    self.updated_by = current_user.employee_id
    self.updated_at = Time.now.to_s(:db)
  end

  def update_attributes_from_old(prior_schedule_a, current_user)
    time = Time.now.to_s(:db)
    file = file_product.index

    prior_schedule_a.attributes.each do |key, value|
      case key
      when "Amended"
        key = "amended"
      when "LandCounty"
        key = "county"
      when "LandState"
        key = "state"
      when "LandAddress"
        key = "land_address"
      when "LandCity"
        key = "land_city"
      when "LandType"
        key = "land_type"
      when "LandZipCode"
        key = "land_zip_code"
      when "LandAddressVerified"
        key = "land_address_verified_at"
        value = prior_schedule_a.EffectiveDT
        self.send("land_address_verified_by" + "=", prior_schedule_a.ModifiedBy)
      when "LandAddressVerifiedPer"
        key = "land_address_verified_per"
      when "LegalDesc"
        key = "legal_description"
        value = file_product.find_replace( AtomicText.rtf_to_html(prior_schedule_a.TextLegal.blank? ? prior_schedule_a.LegalDesc : prior_schedule_a.TextLegal) )
      when "Product"
        key = "product_type"
      when "UseExhibitA"
        key = "use_legal_exhibit_a"
      when "UseVestingExhibitA"
        key = "use_vesting_exhibit_a"
      when "Vesting"
        key = "vesting"
      when "VestingType"
        key = "vesting_type"
      end

      if !EXCLUDE_FIELDS.include?(key) && self.attributes.include?(key)
        self.send(key + "=", (value || nil))
      end
    end
    self.updated_by = current_user.employee_id
    self.updated_at = time

    2.times do |i|
      i += 1
      unless prior_schedule_a.send("Policy#{i}Type").blank?
        policy = Policy.new
        policy.schedule_a_id = self.id
        policy.policy_type_id = PolicyType.where("PolicyDescription = '#{prior_schedule_a.send("Policy#{i}Type")}'").first.ID rescue nil

        names = []
        if i == 1
          file.file_entities.where("Position IN (1, 7)").each do |e|
            names << e.entity.name
          end
          policy.amount = file.SalesPrice
        else
          file.file_entities.where("Position IN (3)").each do |e|
            names << e.entity.name
          end
          policy.amount = file.LoanAmount
        end

        policy.proposed_insured = names.size == 0 ? nil : names.size < 3 ? names.join(" and ") : names[0...-1].join(", ") + ", and " + names[-1]

        policy.created_by = current_user.employee_id
        policy.created_at = time
        policy.updated_by = current_user.employee_id
        policy.updated_at = time
        policy.save

        FileEndorsement.where("FileID = #{file.FileID} AND Product = '#{self.product_type == 'PR' ? "PR~#{policy.type}" : "#{policy.type}"}'").each do |e|
          p_endorsement = PolicyEndorsement.new
          p_endorsement.endorsement_id = e.EndorsementID
          p_endorsement.policy_id = policy.id
          p_endorsement.created_at = time
          p_endorsement.updated_at = time
          p_endorsement.created_by = current_user.employee_id
          p_endorsement.updated_by = current_user.employee_id
        end
      end
    end
  end

  def policy_endorsement_list
    list = []
    self.policy_endorsements.each do |e|
      list << e.endorsement.ShortName
    end
    return list.join(", ")
  end

  def policy_options
    return self.underwriter.nil? || self.version_id.blank? ? [] : self.underwriter.policy_types.where("version_id = #{self.version_id}").collect{|p| [p.PolicyType, p.ID]}
  end

  def endorsement_options
    return self.underwriter.nil? || self.version_id.blank? ? [] : self.underwriter.endorsements.where("version_id = #{self.version_id}").collect{|e| [e.Endorsement, e.EndorsementID]}
  end

  def self.check_boxes ; return ["use_vesting_exhibit_a", "use_legal_exhibit_a", "land_address_verified_by"] ; end
  def underwriter_name ; return self.underwriter.Underwriter ; end
  # def underwriter_id(date = nil) ; return date.nil? ? super() : self.get_history("underwriter_id", date) ; end
  # def county(date = nil) ; return date.nil? ? super() : self.get_history("county", date) ; end
  # def state(date = nil) ; return date.nil? ? super() : self.get_history("state", date) ; end
  # def vesting(date = nil) ; return date.nil? ? super() : self.get_history("vesting", date) ; end
  # def vesting_type(date = nil) ; return date.nil? ? super() : self.get_history("vesting_type", date) ; end
  # def land_address(date = nil) ; return date.nil? ? super() : self.get_history("land_address", date) ; end
  # def land_city(date = nil) ; return date.nil? ? super() : self.get_history("land_city", date) ; end
  # def land_zip_code(date = nil) ; return date.nil? ? super() : self.get_history("land_zip_code", date) ; end
  # def land_type(date = nil) ; return date.nil? ? super() : self.get_history("land_type", date) ; end
  # def legal_description(date = nil) ; return date.nil? ? super() : self.get_history("legal_description", date) ; end
  # def amended(date = nil) ; return date.nil? ? super() : self.get_history("amended", date) ; end
  # def effective_at(date = nil) ; return date.nil? ? super() : self.get_history("effective_at", date) ; end
  # def use_vesting_exhibit_a(date = nil) ; return date.nil? ? super() : self.get_history("use_vesting_exhibit_a", date) ; end
  # def use_vesting_exhibit_a?(date = nil) ; return date.nil? ? super() : self.get_history("use_vesting_exhibit_a", date) == "-1" ; end
  # def use_legal_exhibit_a(date = nil) ; return date.nil? ? super() : self.get_history("use_legal_exhibit_a", date) ; end
  # def use_legal_exhibit_a?(date = nil) ; return date.nil? ? super() : self.get_history("use_legal_exhibit_a", date) == "-1" ; end
  # def land_address_verified_by(date = nil) ; return date.nil? ? super() : self.get_history("land_address_verified_by", date) ; end
  # def land_address_verified_at(date = nil) ; return date.nil? ? super() : self.get_history("land_address_verified_at", date) ; end
  # def land_address_verified_per(date = nil) ; return date.nil? ? super() : self.get_history("land_address_verified_per", date) ; end
  # def version_id(date = nil) ; return date.nil? ? super() : self.get_history("version_id", date) ; end
  # def policies(date = nil) ; date.nil? ? super().where("policies.removed_at IS NULL") : super().where("policies.created_at < '#{date}' AND (policies.removed_at IS NULL OR policies.removed_at > '#{date}')") ; end
  # def policy_endorsements(date = nil) ; date.nil? ? super().where("policy_endorsements.removed_at IS NULL") : super().where("policy_endorsements.created_at < '#{date}' AND (policy_endorsements.removed_at IS NULL OR policy_endorsements.removed_at > '#{date}')") ; end
end
