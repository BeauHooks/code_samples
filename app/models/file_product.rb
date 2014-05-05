class FileProduct < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include AtomicText

  after_create :create_schedule_a

  belongs_to :index,                                           foreign_key: "file_id",     primary_key: "FileID"
  belongs_to :prior,                   class_name: "Index",    foreign_key: "FileID",      primary_key: "prior_id"
  belongs_to :product_type
  has_many   :file_properties,         through: :index
  has_many   :file_entities,           through: :index
  has_one    :schedule_a
  has_many   :policies,                through: :schedule_a
  has_many   :policy_endorsements,     through: :schedule_a
  has_many   :fp_exceptions
  has_many   :fp_requirements
  has_many   :file_product_histories

  # Employee Action-Tracking Relationships
  belongs_to :typed_by,                class_name: "Employee", foreign_key: "TypedBy",     primary_key: "ID"
  belongs_to :reviewed_by,             class_name: "Employee", foreign_key: "ReviewedBy",  primary_key: "ID"
  belongs_to :approved_by,             class_name: "Employee", foreign_key: "ApprovedBy",  primary_key: "ID"
  belongs_to :delivered_by,            class_name: "Employee", foreign_key: "DeliveredBy", primary_key: "ID"

  delegate :DisplayFileID, to: :index,      prefix: false, allow_nil: true
  delegate :Buyer1Name,    to: :index,      prefix: false, allow_nil: true
  delegate :Seller1Name,   to: :index,      prefix: false, allow_nil: true
  delegate :Lender1,       to: :index,      prefix: false, allow_nil: true
  delegate :PolicyType,    to: :PolicyType, prefix: false, allow_nil: true
  delegate :stage,         to: :index,      prefix: false, allow_nil: true

  SELECT_OPTIONS = [["File Number","file_id"],["PR","PR"],["Policy","policy"]]

  SEARCH_DISPLAY = [
                    { label: 'Commitment #', attribute: 'DisplayFileID',  style: 'w150', format: 'to_s',  limit: 0,  to_link: true  },
                    { label: 'Buyer',        attribute: 'Buyer1Name',     style: 'w150', format: 'to_s',  limit: 15, to_link: false },
                    { label: 'Seller',       attribute: 'Seller1Name',    style: 'w100', format: 'to_s',  limit: 15, to_link: false },
                    { label: 'Lender',       attribute: 'Lender1',        style: 'w100', format: 'to_s',  limit: 15, to_link: false },
                    { label: 'Stage',        attribute: 'stage',          style: 'w200', format: 'to_s',  limit: 0,  to_link: false }
                  ]

  EXCLUDE_FIELDS = ["id", "file_id", "file_product_id", "fp_exception_id", "schedule_a_id", "vesting", "underwriter_id", "policy_id", "proposed_insured",
    "created_by", "updated_by", "created_at", "updated_at", "removed_by", "removed_at", "product_type", "product_type_id", "version_id"]

  def get_file
    false
  end

  def create_schedule_a
    type = self.type
    if type == "PR" || type == "Policy"
      file = self.index

      schedule_a = ScheduleA.new
      schedule_a.file_product_id = self.id
      schedule_a.product_type = type
      schedule_a.file_id = self.file_id
      schedule_a.underwriter_id = file.Underwriter
      schedule_a.version_id = RateVersion.where("begins_on <= '#{DateTime.now.beginning_of_day}' AND (ends_on >= '#{DateTime.now.beginning_of_day}' OR ends_on IS NULL)").last.id rescue nil

      property = file.file_properties.first
      if !property.nil?
        schedule_a.county = property.county.CountyName if !property.county.nil?
        schedule_a.state = property.State
        schedule_a.land_address = property.PropertyAddress
        schedule_a.land_city = property.City
        schedule_a.land_zip_code = property.Zip
        schedule_a.legal_description = property.LegalDescription
      end

      transaction = file.TransactionDescription1
      vesting = []
      if transaction == "Refinance" || transaction == "Construction Loan"
        file.file_entities.where("Position IN (1, 7)").each do |e|
          vesting << e.entity.name
        end
      else
        file.file_entities.where("Position = 2").each do |e|
          vesting << e.entity.name
        end
      end

      schedule_a.vesting = vesting.size > 2 ? "#{vesting[0...-1].join(", ")}, and #{vesting[-1]}" : (vesting.join(" and ") || nil)
      schedule_a.use_vesting_exhibit_a = -1 if schedule_a.vesting.to_s.length > 345
      schedule_a.use_legal_exhibit_a = -1 if schedule_a.legal_description.to_s.length > 345
      schedule_a.updated_by = self.created_by
      schedule_a.updated_at = Time.now.to_s(:db)
      schedule_a.save
    end
  end

  def import_prior(prior_file_product_id, current_user)
    prior_product = FileProduct.find prior_file_product_id
    prior = prior_product.index
    time = Time.now.to_s(:db)

    self.prior_id = prior.FileID
    self.save

    schedule_a = self.schedule_a
    schedule_a.update_attributes(prior_product.schedule_a.attributes, current_user)
    schedule_a.file_product_id = self.id
    schedule_a.save

    prior_product.policies.each do |prior_policy|
      policy = prior_policy.dup
      policy.schedule_a_id = self.schedule_a.id

      names = []
      if prior_policy.policy_type.BasedOn == "OWNER"
        self.index.file_entities.where("Position IN (1, 7)").each do |e|
          names << e.entity.name
        end
      else
        self.index.file_entities.where("Position IN (3)").each do |e|
          names << e.entity.name
        end
      end

      policy.proposed_insured = names.size == 0 ? nil : names.size < 3 ? names.join(" and ") : names[0...-1].join(", ") + ", and " + names[-1]

      policy.created_by = current_user.employee_id
      policy.updated_by = current_user.employee_id
      policy.created_at = time
      policy.updated_at = time
      policy.save

      prior_policy.policy_endorsements.each do |prior_endorsement|
        endorsement = prior_endorsement.dup
        endorsement.policy_id = policy.id
        endorsement.created_by = current_user.employee_id
        endorsement.updated_by = current_user.employee_id
        endorsement.created_at = time
        endorsement.updated_at = time
        endorsement.save
      end
    end

    prior_product.fp_exceptions.each do |prior_exception|
      exception = prior_exception.dup
      exception.file_product_id = self.id
      exception.created_by = current_user.employee_id
      exception.updated_by = current_user.employee_id
      exception.created_at = time
      exception.updated_at = time
      exception.save

      prior_exception.fp_requirements.each do |prior_requirement|
        requirement = prior_requirement.dup
        requirement.file_product_id = self.id
        requirement.fp_exception_id = exception.id
        requirement.created_by = current_user.employee_id
        requirement.updated_by = current_user.employee_id
        requirement.created_at = time
        requirement.updated_at = time
        requirement.save
      end
    end

    prior_product.fp_requirements.where("fp_exception_id IS NULL").each do |prior_requirement|
      requirement = prior_requirement.dup
      requirement.file_product_id = self.id
      requirement.created_by = current_user.employee_id
      requirement.updated_by = current_user.employee_id
      requirement.created_at = time
      requirement.updated_at = time
      requirement.save
    end

    self.update_sort_orders
  end

  def import_old_prior(prior_file_product_id, current_user)
    prior_product = FileProductOld.find prior_file_product_id
    prior = prior_product.index
    prior_schedule_a = prior_product.schedule_a_old
    time = Time.now.to_s(:db)

    self.prior_id = prior.FileID
    self.save

    schedule_a = self.schedule_a
    schedule_a.update_attributes_from_old(prior_schedule_a, current_user)
    schedule_a.save

    prior_product.schedule_b_exceptions.each do |prior_exception|
      exception = FpException.new
      exception.file_product_id = self.id
      exception.created_by = current_user.employee_id
      exception.updated_by = current_user.employee_id
      exception.created_at = time
      exception.updated_at = time
      exception.content = find_replace( AtomicText.rtf_to_html(prior_exception.ExceptionText) )
      exception.sort_order = prior_exception.ExceptionNum
      exception.save

      prior_exception.requirements.each do |prior_requirement|
        requirement = FpRequirement.new
        requirement.file_product_id = self.id
        requirement.fp_exception_id = exception.id
        requirement.content = find_replace( AtomicText.rtf_to_html(prior_requirement.RequirementText) )
        requirement.sort_order = prior_requirement.RequirementNum
        requirement.created_by = current_user.employee_id
        requirement.updated_by = current_user.employee_id
        requirement.created_at = time
        requirement.updated_at = time
        requirement.save
      end
    end

    prior_product.requirements.where("ExceptionNum IS NULL").each do |prior_requirement|
      requirement = FpRequirement.new
      requirement.file_product_id = self.id
      requirement.created_by = current_user.employee_id
      requirement.updated_by = current_user.employee_id
      requirement.created_at = time
      requirement.updated_at = time
      requirement.content = find_replace( AtomicText.rtf_to_html(prior_requirement.RequirementText) )
      requirement.sort_order = prior_requirement.RequirementNum
      requirement.save
    end

    self.update_sort_orders
  end

  def import_base(base_id, current_user)
    base = BaseFile.find base_id
    time = Time.now.to_s(:db)
    base_product = base.base_products.where("product_type_id = #{self.product_type_id}").first

    schedule_a = self.schedule_a

    base_product.base_schedule_a.attributes.each do |key, value|
      schedule_a.send(key + "=", (value || nil) ) unless !schedule_a.attributes.include?(key) || EXCLUDE_FIELDS.include?(key)
    end

    schedule_a.updated_by = current_user.employee_id
    schedule_a.updated_at = time
    schedule_a.save

    base_product.base_policies.each do |base_policy|
      policy = Policy.new
      policy.schedule_a_id = schedule_a.id
      base_policy.attributes.each do |key, value|
        policy.send(key + "=", (value || nil) ) unless !policy.attributes.include?(key) || EXCLUDE_FIELDS.include?(key)
      end

      names = []
      if policy.policy_type.BasedOn == "OWNER"
        self.index.file_entities.where("Position IN (1, 7)").each do |e|
          names << e.entity.name
        end
      else
        self.index.file_entities.where("Position IN (3)").each do |e|
          names << e.entity.name
        end
      end

      policy.proposed_insured = names.size == 0 ? nil : names.size < 3 ? names.join(" and ") : names[0...-1].join(", ") + ", and " + names[-1]

      policy.created_by = current_user.employee_id
      policy.created_at = time
      policy.updated_by = current_user.employee_id
      policy.updated_at = time
      policy.save

      base_policy.base_policy_endorsements.each do |base_endorsement|
        endorsement = PolicyEndorsement.new
        endorsement.policy_id = base_endorsement.id
        base_endorsement.attributes.each do |key, value|
          endorsement.send(key + "=", (value || nil) ) unless !endorsement.attributes.include?(key) || EXCLUDE_FIELDS.include?(key)
        end
        endorsement.created_by = current_user.employee_id
        endorsement.updated_by = current_user.employee_id
        endorsement.created_at = time
        endorsement.updated_at = time
        endorsement.save
      end
    end

    base_product.base_product_exceptions.each do |base_exception|
      exception = FpException.new
      exception.file_product_id = self.id

      base_exception.attributes.each do |key, value|
        exception.send(key + "=", (value || nil) ) unless !exception.attributes.include?(key) || EXCLUDE_FIELDS.include?(key)
      end

      exception.created_by = current_user.employee_id
      exception.created_at = time
      exception.updated_by = current_user.employee_id
      exception.updated_at = time
      exception.save

      base_exception.base_product_requirements.each do |base_requirement|
        requirement = FpRequirement.new
        requirement.file_product_id = self.id
        requirement.fp_exception_id = exception.id

        base_requirement.attributes.each do |key, value|
          requirement.send(key + "=", (value || nil) ) unless !requirement.attributes.include?(key) || EXCLUDE_FIELDS.include?(key)
        end

        requirement.created_by = current_user.employee_id
        requirement.created_at = time
        requirement.updated_by = current_user.employee_id
        requirement.updated_at = time
      end
    end

    base_product.base_product_requirements.where("base_product_exception_id IS NULL").each do |base_requirement|
      requirement = FpRequirement.new
      requirement.file_product_id = self.id

      base_requirement.attributes.each do |key, value|
        requirement.send(key + "=", (value || nil) ) unless !requirement.attributes.include?(key) || EXCLUDE_FIELDS.include?(key)
      end

      requirement.created_by = current_user.employee_id
      requirement.created_at = time
      requirement.updated_by = current_user.employee_id
      requirement.updated_at = time
      requirement.save
    end

    self.update_sort_orders
  end

  def import_old_base(base_id, current_user)
    base = FileBase.find base_id
    schedule_a = self.schedule_a
    time = Time.now.to_s(:db)

    schedule_a.attributes.each do |key, value|
      unless EXCLUDE_FIELDS.include?(key)
        schedule_a.send(key + "=", nil)
      end
    end

    schedule_a.land_address = base.Address1
    schedule_a.land_city = base.PropertyCity
    schedule_a.land_zip_code = base.PropertyZip
    schedule_a.state = base.PropertyState
    schedule_a.county = base.county.CountyName unless base.county.nil?
    schedule_a.legal_description = find_replace( AtomicText.rtf_to_html(base.Legal1) )
    schedule_a.effective_at = base.EffectiveDateShort
    schedule_a.vesting_type = base.LandType
    schedule_a.land_type = base.PropertyType
    schedule_a.updated_by = current_user.employee_id
    schedule_a.updated_at = time
    schedule_a.save

    current_exception = self.all_exceptions.size
    current_requirement = self.all_requirements.size
    base.file_exceptions.each do |base_exception|
      exception = FpException.new
      exception.file_product_id = self.id
      exception.content = find_replace( AtomicText.rtf_to_html(base_exception.ExceptionText) )
      exception.sort_order = current_exception += 1
      exception.created_by = current_user.employee_id
      exception.created_at = time
      exception.updated_by = current_user.employee_id
      exception.updated_at = time
      exception.save

      unless base_exception.EntryNum.blank?
        koi = RecordingKoi.find(:all, joins: [:recording_entries], conditions: ["tblUTEntry.entrynumber = '#{base_exception.EntryNum}' AND CountyID = #{self.index.county_id}"] ).first
        unless koi.nil?
          exception_type = koi.ExceptionType
          exception_template = ExceptionTemplate.where("ExceptionType = '#{exception_type}'").first
          requirement_template = exception_template.requirement_template unless exception_template.nil?
          unless requirement_template.nil?
            entry = RecordingEntry.where("entrynumber = '#{base_exception.EntryNum}' AND CountyID = #{self.index.county_id}").first
            requirement = FpRequirement.new
            requirement = FpRequirement.new
            requirement.file_product_id = self.id
            requirement.fp_exception_id = exception.id
            requirement.sort_order = current_requirement += 1
            requirement.created_by = current_user.employee_id
            requirement.updated_by = current_user.employee_id
            requirement.created_at = time
            requirement.updated_at = time
            requirement.content = find_replace( AtomicText.rtf_to_html(requirement_template.template_text, entry) )
            requirement.save
          end
        end
      end
    end
  end

  def update_sort_orders
    current = StandardException.find(:all).size
    FpException.where("file_product_id = #{self.id}").each do |record|
      record.sort_order = current += 1
      record.save
    end

    current = StandardRequirement.find(:all).size
    FpRequirement.where("file_product_id = #{self.id}").each do |record|
      record.sort_order = current += 1
      record.save
    end

    current = 0
    Policy.where("schedule_a_id = #{self.schedule_a.id} AND removed_at IS NULL").each do |policy|
      policy.sort_order = current += 1
      policy.save
    end
  end

  def find_replace(content, entry = nil)
    scan = content.scan(/~(.*?)~/)
    schedule_a = self.schedule_a
    file = self.index
    reference = entry.nil? ? nil : entry.reference

    scan.each do |field|
      key = field[0].gsub(/[^0-9A-Za-z_]/, "")
      case key
      when "Amount", "amount", "consideration"
        value = entry.blank? || entry.consideration.blank? ? nil : number_to_currency(entry.consideration, unit: "$")
      when "Book"
        value = entry.blank? ? nil : entry.Book
      when "CurrentYear"
        value = Time.now.year
      when "DatedDate"
        value = entry.blank? || entry.DocumentDate.blank? ? nil : entry.DocumentDate.strftime("%B %-d, %Y").gsub(/\s\s/, " ")
      when "EntryNum"
        value = entry.blank? || entry.entrynumber.blank? ? nil : entry.entrynumber.to_i
      when "FromParty"
        value = entry.blank? ? nil : entry.fromparty
      when "ForParty"
        value = entry.blank? ? nil : entry.recordedfor
      when "KOI", "koi"
        value = entry.blank? || entry.koi.blank? ? nil : RecordingKoi.where("koi = #{entry.koi}").first.description rescue nil
      when "PriorYear"
        value = Time.now.year - 1.years
      when "ProposedInsured"
        value = schedule_a.policies[0].proposed_insured
      when "RecordedDate"
        value = entry.blank? || entry.filingdate.blank? ? nil : entry.filingdate.strftime("%B %-d, %Y").gsub(/\s\s/, " ")
      when "RecordedTime"
        value = entry.blank? || entry.filingtime.blank? ? nil : entry.filingtime.strftime("%l:%M %p").gsub(/\s\s/, " ")
      when "ReferenceBook"
        value = reference.blank? ? nil : reference.Book
      when "ReferenceEntryNum"
        value = reference.blank? ? nil : reference.entrynumber
      when "ReferenceStartPage"
        value = reference.blank? ? nil : reference.Page
      when "ReferenceEndPage"
        value = reference.blank? ? nil : reference.EndPage
      when "RecordedDate"
        value = reference.blank? || reference.filingdate.blank? ? nil : reference.filingdate.strftime("%B %-d, %Y").gsub(/\s\s/, " ")
      when "StartPage"
        value = entry.blank? ? nil : entry.Page
      when "TaxSerialNum"
        value = entry.blank? ? nil : entry.taxid
      when "ToParty", "toparty"
        value = entry.blank? ? nil : entry.toparty
      when "Vestee", "Vesting"
        value = schedule_a.vesting
      else
        if !entry.nil? && entry.attributes.include?(key)
          value = entry.send(key)
        end
      end
      value = "{{#{key}}}" if value.blank?
      content = content.gsub("~#{key}~", "#{value}")
    end
    return content
  end
  # def fp_exceptions(date = nil) ; date.nil? ? super().where("fp_exceptions.removed_at IS NULL") : super().where("fp_exceptions.created_at < '#{date}' AND (fp_exceptions.removed_at IS NULL OR fp_exceptions.removed_at > '#{date}')") ; end
  # def fp_requirements(date = nil) ; date.nil? ? super().where("fp_requirements.removed_at IS NULL") : super().where("fp_requirements.created_at < '#{date}' AND (fp_requirements.removed_at IS NULL OR fp_requirements.removed_at > '#{date}')") ; end
  # def policies(date = nil) ; date.nil? ? super().where("policies.removed_at IS NULL") : super().where("policies.created_at < '#{date}' AND (policies.removed_at IS NULL OR policies.removed_at > '#{date}')") ; end
  # def policy_endorsements(date = nil) ; date.nil? ? super().where("policy_endorsements.removed_at IS NULL") : super().where("policy_endorsements.created_at < '#{date}' AND (policy_endorsements.removed_at IS NULL OR policy_endorsements.removed_at > '#{date}')") ; end
  def type
    self.product_type.name
  end

  def exception_collection
    self.fp_exceptions.collect{|e| [e.sort_order, e.id]}
  end

  def standard_exceptions
    StandardException.find(:all)
  end

  def standard_requirements
    StandardRequirement.find(:all)
  end

  def all_exceptions
    self.standard_exceptions + self.fp_exceptions
  end

  def all_requirements
    self.standard_requirements + self.fp_requirements
  end

end
