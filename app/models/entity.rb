class Entity < ActiveRecord::Base
  self.table_name  = "tblEntities"
  self.primary_key = "EntityID"

  attr_defaults :FullName => { :default => "", :if => :blank? }

  alias_attribute :prefix, :Prefix
  alias_attribute :first_name, :FirstName
  alias_attribute :middle_initial, :MiddleInitial
  alias_attribute :last_name, :LastName
  alias_attribute :suffix, :Suffix
  alias_attribute :dummy_time, :DummyTime

  before_save :update_full_name, :changed_indcorp
  # :normalize_name

  default_scope { where("MasterEntity = 0") }

  # @favorites = Entity.find(:all, group: "tblEntities.EntityID", joins: [:employee_rolodexes], conditions: ["tblEmployeeRolodex.EmployeeID = #{current_user.employee_id} AND tblEntities.IsActive != 0 "], order: "tblEntities.FullName ASC")

  TYPES = [ "Company", "Corporation", "Financial Institution", "Individual", "LLC", "Trust", "Organization", "Partnership" ]
  SEARCH_OPTIONS = [ ["Name", "name"], ["Address", "address"], ["E-Mail", "email"], ["Phone", "phone"], ["UserID", "userid"] ]
  SELECT_OPTIONS = [ ["Name", "name"], ["Address", "address"], ["E-Mail", "email"], ["Phone", "phone"], ["UserID", "userid"] ]

  SEARCH_DISPLAY = [
                    { label: 'Name',                attribute: 'name_last_first',          style: 'name',            format: 'to_s',   limit: 15, to_link: false, link_type: '' },
                    { label: 'Description',         attribute: 'Description',              style: 'description',     format: 'to_s',   limit: 15, to_link: false, link_type: ''  },
                    { label: 'Primary Affiliation', attribute: 'primary_affiliation_name', style: 'affiliation',     format: 'to_s',   limit: 15, to_link: false, link_type: ''  },
                    { label: 'Phone',               attribute: 'primary_phone_number',     style: 'phone',           format: 'to_s',   limit: 0,  to_link: true,  link_type: 'phone'  },
                    { label: 'Email',               attribute: 'Email',                    style: 'email',           format: 'to_s',   limit: 15, to_link: true,  link_type: 'email'  },
                    { label: 'Address',             attribute: 'primary_address',          style: 'rolodex_address', format: 'to_s',   limit: 15, to_link: false, link_type: ''  },
                    { label: 'City',                attribute: 'primary_city',             style: 'city',            format: 'to_s',   limit: 15, to_link: false, link_type: ''  },
                    { label: 'State',               attribute: 'primary_state',            style: 'state',           format: 'to_s',   limit: 0,  to_link: false, link_type: ''  }
                  ]

  has_many   :rolodex_signatures,                                            foreign_key: "entity_id",      primary_key: "EntityID"
  has_many   :hud_line_payments,                                             foreign_key: "entity_id",      primary_key: "EntityID"
  has_many   :file_doc_entities,                                             foreign_key: "entity_id",      primary_key: "EntityID"
  belongs_to :parent,                      class_name: "Entity",             foreign_key: "MasterEntityID", primary_key: "EntityID"
  has_many   :children,                    class_name: "Entity",             foreign_key: "MasterEntityID", primary_key: "EntityID", order: "EntityID"
  has_many   :counties_im_payee_for,       class_name: "County",             foreign_key: "PayeeID",        primary_key: "EntityID", order: "CountyID"
  has_many   :deliveries,                                                    foreign_key: "EntityID",       primary_key: "EntityID", order: "FileID, EnteredDT"
  has_many   :file_entities,                                                 foreign_key: "EntityID",       primary_key: "EntityID", order: "FileID"
  has_many   :files_as_buyer_1,            class_name: "FileInfo",           foreign_key: "Buyer1",         primary_key: "EntityID", order: "CompanyID, FileID"
  has_many   :files_as_buyer_2,            class_name: "FileInfo",           foreign_key: "Buyer2",         primary_key: "EntityID", order: "CompanyID, FileID"
  has_many   :files_as_seller_1,           class_name: "FileInfo",           foreign_key: "Seller1",        primary_key: "EntityID", order: "CompanyID, FileID"
  has_many   :files_as_seller_2,           class_name: "FileInfo",           foreign_key: "Seller2",        primary_key: "EntityID", order: "CompanyID, FileID"
  has_many   :files_as_lender,             class_name: "FileInfo",           foreign_key: "Lender1",        primary_key: "EntityID", order: "CompanyID, FileID"
  has_many   :messages
  has_many   :recipients
  has_one    :company_info,                class_name: "Company",            foreign_key: "EntityID",       primary_key: "EntityID" # If this entity is one of the TMI companies, reference to the Company record
  has_many   :cpls,                   class_name: "ClosingProtectionLetter", foreign_key: "lender_id",      primary_key: "EntityID"

  # Entity Affiliation Relationships
  has_many   :affiliations_as_entity_1,    class_name: "EntityAffiliation",  foreign_key: "EntityID1",      primary_key: "EntityID", order: "DummyTime DESC", conditions: "IsActive = -1 AND IsInactive = 0"
  has_many   :affiliations_as_entity_2,    class_name: "EntityAffiliation",  foreign_key: "EntityID2",      primary_key: "EntityID", order: "DummyTime DESC", conditions: "IsActive = -1 AND IsInactive = 0"
  has_many   :affiliations_as_contact_1,   class_name: "EntityAffiliation",  foreign_key: "ContactID1",     primary_key: "EntityID", order: "DummyTime DESC", conditions: "IsActive = -1 AND IsInactive = 0"
  has_many   :affiliations_as_contact_2,   class_name: "EntityAffiliation",  foreign_key: "ContactID2",     primary_key: "EntityID", order: "DummyTime DESC", conditions: "IsActive = -1 AND IsInactive = 0"

  # Contact Information
  has_many   :entity_contacts,                                               foreign_key: "EntityID",       primary_key: "EntityID"
  # has_one    :primary_office, through: :entity_contacts, conditions: where("ContactDesc IN ('Cell') AND IsPrimary = -1 AND IsActive = -1 AND ContactType = 'CONTACT'").first
  # has_one    :primary_cell, through: :entity_contacts, conditions: where("ContactDesc IN ('Cell') AND IsPrimary = -1 AND IsActive = -1 AND ContactType = 'CONTACT'").first

  has_many   :addresses,                   class_name: "EntityContact",      foreign_key: "EntityID",       primary_key: "EntityID", order: "IsPrimary ASC, EnteredDT DESC", conditions: ["IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'"]
  has_many   :contact_infos,               class_name: "EntityContact",      foreign_key: "EntityID",       primary_key: "EntityID", order: "IsPrimary ASC, EnteredDT DESC", conditions: ["IsActive = -1 AND IsInactive = 0 AND ContactType = 'CONTACT'"]

  # Sourced Contacts???
  has_many   :sourced_contacts,            class_name: "EntityContact",      foreign_key: "SourceEntityID", primary_key: "EntityID"
  has_many   :entity_contacts_as_source,   class_name: "EntityContact",      foreign_key: "SourceEntityID", primary_key: "EntityID", order: "ContactType, ContactDesc, Description"
  has_many   :entity_images,                                                 foreign_key: "EntityID",       primary_key: "EntityID"
  has_many   :entity_images_as_contact,    class_name: "EntityImage",        foreign_key: "ContactID",      primary_key: "EntityID", order: "EntityID, ImageType, ScanDate, FileName"
  has_many   :entity_names,                                                  foreign_key: "EntityID",       primary_key: "EntityID", order: "Name"
  has_many   :entity_notaries,                                               foreign_key: "EntityID",       primary_key: "EntityID", order: "UserSigID, NotaryType, NotaryCounty, NotaryState"
  has_many   :entity_notes,                                                  foreign_key: "EntityID",       primary_key: "EntityID", order: "NoteDT DESC"
  has_many   :entity_permissions,                                            foreign_key: "EntityID",       primary_key: "EntityID", order: "FTPermissionID, DummyTime DESC"
  has_many   :entity_rules,                                                  foreign_key: "EntityID",       primary_key: "EntityID", order: "RuleType, RuleDT"
  has_many   :entity_rules_as_contact,     class_name: "EntityRule",         foreign_key: "ContactID",      primary_key: "EntityID", order: "RuleType, RuleDT"
  has_many   :entity_signatures,                                             foreign_key: "EntityID",       primary_key: "EntityID", order: "SigType, Description"
  has_many   :sourced_signatures,          class_name: "EntitySignature",    foreign_key: "SourceEntityID", primary_key: "EntityID"
  has_many   :entity_signatures_as_source, class_name: "EntitySignature",    foreign_key: "SourceEntityID", primary_key: "EntityID", order: "SigType, Description"
  has_many   :employee_rolodexes,                                            foreign_key: "EntityID"
  belongs_to :company,                                                       foreign_key: "CompanyID",      primary_key: "CompanyID"
  belongs_to :county,                                                        foreign_key: "CountyID",       primary_key: "CountyID"

  # Employee Action-Tracking Relationships
  belongs_to :entered_by,                  class_name: "Employee",           foreign_key: "EnteredBy",      primary_key: "ID"
  belongs_to :reviewed_by,                 class_name: "Employee",           foreign_key: "ReviewedBy",     primary_key: "ID"

  delegate :primary_phone, to: :entity_contacts
  delegate :primary_email, to: :entity_contacts
  delegate :primary_fax, to: :entity_contacts

  validates_inclusion_of :IndCorp, :in => TYPES
  validates :company, presence: true

  def primary_office
    primary = self.entity_contacts.where("ContactDesc IN ('Office') AND IsPrimary = -1 AND IsActive = -1 AND ContactType = 'CONTACT'").first
    if primary
      return primary
    else
      return self.entity_contacts.where("ContactDesc IN ('Office') AND IsActive = -1 AND ContactType = 'CONTACT'").order("ContactID DESC").first
    end
  end

  def primary_cell
    primary = self.entity_contacts.where("ContactDesc IN ('Cell') AND IsPrimary = -1 AND IsActive = -1 AND ContactType = 'CONTACT'").first
    if primary
      return primary
    else
      return self.entity_contacts.where("ContactDesc IN ('Cell') AND IsActive = -1 AND ContactType = 'CONTACT'").order("ContactID DESC").first
    end
  end

  def full_name
    self.FullName.strip ||= "#{self.FirstName ||= ''} #{self.MiddleInitial ||= ''} #{self.LastName ||= ''}"
  end

  def name_last_first
    if self.IndCorp == "Individual"
      if !self.MiddleInitial.blank? && !self.LastName.blank?
        "#{self.LastName}, #{self.FirstName} #{self.MiddleInitial}"
      elsif !self.LastName.blank?
        "#{self.LastName}, #{self.FirstName}"
      else
        "#{self.FullName}"
      end
    else
      if !self.FirstName.blank? && self.LastName.blank? && self.MiddleInitial.blank?
        self.FirstName
      else
        "#{self.FullName}"
      end
    end
  end

  def search_options
    SEARCH_OPTIONS
  end

  def search_display
    SEACH_DISPLAY
  end

  def types
    TYPES
  end

  def rolodex_address
    "#{self.primary_address.Address}"
  end

  def self.search_by_type(type, search_text, include_inactive)
    include_inactive ? active = "" : active = "AND IsActive = -1"
    case type
    when "name"
      where("FullName LIKE '#{search_text.gsub("*","%").gsub("'", "\\\\'")}%' #{active}")
    when "address"
      where("primary_address LIKE '#{search_text.gsub("*","%").gsub("'", "\\\\'")}%' #{active}")
    when "email"
      where("Email LIKE '#{search_text.gsub("*","%").gsub("'", "\\\\'")}%' #{active}")
    when "phone"
      where("primary_phone_number LIKE '%#{search_text.gsub("*","%").gsub("'", "\\\\'")}%' #{active}")
    when "userid"
      where("OldUserID = '#{search_text.gsub("'", "")}' #{active}")
    end
  end

  def get_weight
    weight = 0

    unless self.LastModifiedDT == nil
      days = Time.now - self.LastModifiedDT
      days = ((days+800)/(60*60*24)).to_i * -1
      case days
      when 0..30
        weight += 6
      when 31..90
        weight += 4
      when 91..180
        weight += 2
      when 181..365 # 2-4 years
        weight += 1
      when 730..1460 # 4+ years since use
        weight -= 1
      else
        weight -= 2
      end
    end

    unless self.LastUsedDT == nil
      days = Time.now - self.LastUsedDT
      days = ((days+800)/(60*60*24)).to_i * -1
      if days <= 90
        weight += 1
      elsif days > 365
        weight -= 1
      end
    else
      weight -= 1
    end

    files = self.FileCount.to_i
    if files >= 5
      weight += 2
    elsif files > 1 && files < 5
      weight += 1
    end
    weight
  end

  def update_last_modified
    self.LastModifiedDT = Time.now.to_s(:db)
    self.Weighted = self.get_weight
    self.save
  end

  def add_to_file_count
    self.FileCount = self.FileCount.to_i + 1
    self.LastUsedDT = Time.now.to_s(:db)
    self.Weighted = self.get_weight
    self.save
  end

  def subtract_from_file_count
    self.FileCount = self.FileCount.to_i - 1
    self.Weighted = self.get_weight
    self.save
  end

  def belongs_to_employee?(employee_id)
    self.employee_rolodexes.where("EmployeeID = #{employee_id}").first != nil
  end

  def self.ind_corp_options
    options = []

    TYPES.each do |type|
      options << [type, type]
    end
    options
  end

  def first_phone
    self.entity_contacts.phones_callable.first.Contact unless self.entity_contacts.phones_callable.first.nil?
  end

  def first_fax
    self.entity_contacts.fax.first.Contact unless self.entity_contacts.fax.first.nil?
  end

  def self.smart_find(value)
    return value if value.is_a?(Entity)
    return nil   if value.nil?
    if value.to_s =~ /^\d+$/
      return (self.find(value.to_i) rescue nil)
    end
    value  = "'#{value.to_s.strip}'"
    conds  = "SOUNDEX(FullName) LIKE SOUNDEX(#{value}) OR SOUNDEX(FirstName) LIKE SOUNDEX(#{value}) OR SOUNDEX(LastName) LIKE SOUNDEX(#{value}) OR SOUNDEX(MiddleInitial) LIKE SOUNDEX(#{value})"
    set    = Entity.where(conds)
  end

  def self.name_includes(pattern)
    pattern = search_pattern(pattern)
    where(
      :Prefix.matches        % pattern |
      :FirstName.matches     % pattern |
      :MiddleInitial.matches % pattern |
      :LastName.matches      % pattern |
      :Suffix.matches        % pattern |
      :FullName.matches      % pattern
    )
  end

  def self.description_includes(pattern)
    where(:Description =~ search_pattern(pattern))
  end

  def self.type_includes(pattern)
    where(:CustomerType =~ search_pattern(pattern))
  end

  # Create a new entity the correct way, merging as necessary
  def self.make(options = {})
    e = self.new(options)
    if e.FirstName.blank?
      tmp = e.FullName
      e.MiddleInitial = e.LastName = e.Suffix = nil
      e.FirstName = tmp
    end
    match = self.first(:conditions => [
      'CompanyID = ? AND FullName = ? AND IsActive = ?',
      e.CompanyID, e.FullName, true
    ])
    return match if match
    return e if e.save and e.normalize
    e.delete unless e.new_record?
    nil
  end

  # Merge this new record (must be saved) with other entities
  def normalize
    if Entity.exists?(['EntityID <> ? AND CompanyID = ? AND FullName = ? AND IsActive = ?', self.id, self.CompanyID, self.FullName, true])

      # This entity must be grouped
      tmp = Entity.first(:conditions => [
        'EntityID <> ? AND CompanyID = ? AND FullName = ? AND IsActive = ? AND SubEntity = ?',
        self.id, self.CompanyID, self.FullName, true, true
      ])
      if tmp
        master_id = tmp.MasterEntityID
      else
        tmp = Entity.create!(
          :FirstName     => self.FirstName,
          :MiddleInitial => self.MiddleInitial,
          :LastName      => self.LastName,
          :Suffix        => self.Suffix,
          :FullName      => self.FullName,
          :CompanyID     => self.CompanyID,
          :MasterEntity  => true,
          :SubEntity     => false,
          :IndCorp       => self.IndCorp,
          :EnteredBy     => self.EnteredBy,
          :EnteredDT     => self.EnteredDT
        )
        master_id = tmp.id
        Entity.all(:conditions => [
          'EntityID NOT IN(?, ?) AND CompanyID = ? FullName = ? AND IsActive = ?',
          self.id, tmp.id, self.CompanyID, self.FullName, true
        ]).each do |other|
          other.MasterEntityID = master_id
          other.MasterEntity   = false
          other.SubEntity      = true
          EntityImage.update_all(      "EntityID  = #{master_id}, ContactID  = #{other.id}", "EntityID  = #{other.id}")
          EntityRule.update_all(       "EntityID  = #{master_id}, ContactID  = #{other.id}", "EntityID  = #{other.id}")
          EntityAffiliation.update_all("EntityID1 = #{master_id}, ContactID1 = #{other.id}", "EntityID1 = #{other.id} OR ContactID1 = #{other.id}")
          EntityAffiliation.update_all("EntityID2 = #{master_id}, ContactID2 = #{other.id}", "EntityID2 = #{other.id} OR ContactID2 = #{other.id}")
        end
      end
      self.MasterEntityID = master_id
      self.SubEntity      = true
    else
      # This user need not be grouped
      self.MasterEntityID = nil
      self.SubEntity      = false
    end
    self.IsActive     = true
    self.MasterEntity = false
    return true if self.save
    self.denormalize! # roll back any normalization we've done
    false
  end

  def is_master?
    self.MasterEntity == 0 ? true : false
  end

  # Call this in preparation to delete an entity. This ensures that the merge-
  # state of records is maintained.
  #
  # The assumption is that self is a saved, normalized record. Note that
  # calling this on a master record that has more than one child record will
  # raise an exception.
  #
  def denormalize!
    # Handle denormalization of containers
    if self.MasterEntity
      raise "Can't denormalize master entity with more than one child!" if self.children.length > 1
      child = self.children.first
      if child
        # Promote child to an independent record
        child.MasterEntityID = nil
        child.MasterEntity   = false
        child.SubEntity      = false
        child.save!
        EntityImage.update_all(      "EntityID  = #{child.id}, ContactID  = 0", "EntityID  = #{self.id}")
        EntityRule.update_all(       "EntityID  = #{child.id}, ContactID  = 0", "EntityID  = #{self.id}")
        EntityAffiliation.update_all("EntityID1 = #{child.id}, ContactID1 = 0", "EntityID1 = #{self.id}")
        EntityAffiliation.update_all("EntityID2 = #{child.id}, ContactID2 = 0", "EntityID2 = #{self.id}")
      else
        # We're just an empty container, make us a regular, independent record
        EntityImage.update_all(      "EntityID  = ContactID,  ContactID  = 0", "EntityID  = #{self.id}")
        EntityRule.update_all(       "EntityID  = ContactID,  ContactID  = 0", "EntityID  = #{self.id}")
        EntityAffiliation.update_all("EntityID1 = ContactID1, ContactID1 = 0", "EntityID1 = #{self.id}")
        EntityAffiliation.update_all("EntityID2 = ContactID2, ContactID2 = 0", "EntityID2 = #{self.id}")
      end
      self.Description    = "." if self.Description.blank? # allow validations to pass
      self.IsActive       = false
      self.MasterEntityID = nil
      self.MasterEntity   = false
      self.SubEntity      = false
      self.save!
      return
    end

    # Handle denormalization of contained entities
    if self.parent
      if self.parent.children.length <= 1
        # Nuke parent since we don't have any siblings
        EntityImage.update_all(      "EntityID  = #{self.id}, ContactID  = 0", "EntityID  = #{parent.id}")
        EntityRule.update_all(       "EntityID  = #{self.id}, ContactID  = 0", "EntityID  = #{parent.id}")
        EntityAffiliation.update_all("EntityID1 = #{self.id}, ContactID1 = 0", "EntityID1 = #{parent.id}")
        EntityAffiliation.update_all("EntityID2 = #{self.id}, ContactID2 = 0", "EntityID2 = #{parent.id}")
        self.parent.delete
      end
    end
    self.IsActive       = false
    self.MasterEntityID = nil
    self.SubEntity      = false
    self.save!
  end

  # Provide railsy accessors to the name field(s), including logic to keep the
  # full name updated if the name is changed
  #
  def name
    if self.IndCorp == "Individual"
      if self.MiddleInitial != nil
        return "#{self.FirstName} #{self.MiddleInitial} #{self.LastName}"
      elsif self.FirstName != nil || self.LastName != nil
        return "#{self.FirstName} #{self.LastName}"
      else
        return "#{self.FullName}"
      end
    else
      if self.FirstName != nil && self.FirstName != "" && (self.LastName == nil || self.LastName == "") && (self.MiddleInitial == nil || self.MiddleInitial == "")
        return self.FirstName
      else
        return "#{self.FullName}"
      end
    end
  end

  # Provide railsy accessors to the entity contact field(s)
  def email
    self.entity_contacts.where("ContactType = 'CONTACT' AND ContactDesc = 'Email' ").each do |i|
      if i.Primary == -1
        return i.Contact
      end
    end

    self.entity_contacts.where("ContactType = 'CONTACT' AND ContactDesc = 'Email' ").reverse.each do |i|
      if i.IsActive == -1 && i.IsInactive == 0
        return i.Contact
      end
    end

    return self.Email.to_s
  end

  # Address returned as array for Address1, City, State, and Zip
  def address
    address = ["", "", "", ""]
    primary = self.entity_contacts.where("IsPrimary = -1 AND IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'").first

    if primary != nil
      return [primary.Address.to_s, primary.City.to_s, primary.abbreviation.to_s, primary.Zip.to_s]
    end

    last = self.entity_contacts.where("IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'").last
    if last != nil
      return [last.Address.to_s, last.City.to_s, last.abbreviation.to_s, last.Zip.to_s]
    end

    address
  end

  # Address returned as array for Address1, Address2, City, State, and Zip
  def address_with_2
    address = ["", "", "", "", ""]
    primary = self.entity_contacts.where("IsPrimary = -1 AND IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'").first

    if primary != nil
      return [primary.Address.to_s, primary.Address2.to_s, primary.City.to_s, primary.abbreviation.to_s, primary.Zip.to_s]
    end

    first = self.entity_contacts.where("IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'").first
    if first != nil
      return [first.Address.to_s, first.Address2.to_s, first.City.to_s, first.abbreviation.to_s, first.Zip.to_s]
    end

    address
  end

  # Address returned as array for Address1, Address2, City, State, Zip, AND County
  def full_address
    address = ["", "", "", "", ""]
    primary = self.entity_contacts.where("IsPrimary = -1 AND IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'").first

    if primary != nil
      return [primary.Address.to_s, primary.Address2.to_s, primary.City.to_s, primary.abbreviation.to_s, primary.Zip.to_s, primary.County.to_s]
    end

    first = self.entity_contacts.where("IsActive = -1 AND IsInactive = 0 AND ContactType = 'ADDRESS'").first
    if first != nil
      return [first.Address.to_s, first.Address2.to_s, first.City.to_s, first.abbreviation.to_s, first.Zip.to_s, first.County.to_s]
    end

    address
  end

  # OPTIMIZE - Gets the contact's send method if it is not email. Let email condition in view to support mail_to link
  def effective_date
    unless self.EffectiveDate.blank?
      date = self.EffectiveDate.to_s.split("-")
      day = date[2]
      month = date[1]
      year = date[0]
      "#{day}/#{month}/#{year}"
    end
  end

  # Affiliation - Check for Primary, Spouce, then just take the first record if there is one.
  def primary_affiliation
    unless self.primary_affiliation_id.nil?
      affiliation = self.affiliations_as_entity_1.where("EntityID2 = #{self.primary_affiliation_id}").first
      affiliation = self.affiliations_as_entity_2.where("EntityID1 = #{self.primary_affiliation_id}").first if affiliation == nil
      affiliation
    end
  end

  # Employee. Brings up the first one in the list because we don't have a primary field.
  def employee
    unless self.employee_rolodexes.first.nil?
      employee = self.employee_rolodexes.all(order: "updated_at ASC").last.employee
      employee.FullName if employee != nil
    end
  end

  # Open Files Size
  def open_files
    return Index.find(:all, conditions: ["tblFileEntities.EntityID = #{self.EntityID} AND tblFileInfo.IsClosed != -1"], include: [:file_entities], order: ["tblFileInfo.DisplayFileID DESC"]).size
  end

  def show_rules
    array = []
    if self.entity_rules.first != nil
      self.entity_rules.each do |i|
        if i.IsActive == -1 && i.IsInactive == 0
          array << [i.RuleText, i.ID]
        end
      end
    end

    if self.entity_rules_as_contact.first != nil
      self.entity_rules_as_contact.each do |i|
        if i.IsActive == -1 && i.IsInactive == 0
          array << [i.RuleText, i.ID]
        end
      end
    end

    array
  end

  def has_rules?
    Rule.check_entity(self).size > 0
  end

  def get_rules(trigger = nil)
    Rule.check_entity(self, trigger)
  end

  private

  # Before Save hooks
  def update_full_name
    if self.IndCorp == "Individual" && (self.FirstName_changed? || self.MiddleInitial_changed? || self.LastName_changed?)
      self.FullName = "#{self.LastName}, #{self.FirstName} #{self.MiddleInitial}".upcase
    end
  end

  def changed_indcorp
    if self.IndCorp != "Individual"
      self.entity_contacts.active_emails.each do |email|
        email.remove_primary
        email.inactive
      end
    end
  end
  ##

  # Helper for class-level search filter methods
  def self.search_pattern(pattern)
    pattern = "%#{pattern}" unless pattern.first == "%"
    pattern = "#{pattern}%" unless pattern.last  == "%"
    pattern
  end

  # Normalize all newly instantiated objects' names
  def after_initialize
    return unless new_record?
    if self.FirstName.blank?
      tmp_name = self.FullName
      self.MiddleInitial = self.LastName = self.Suffix = nil
      self.FirstName = tmp_name
    end
  end

  # Call to update the name fields according to the entity's type (individual
  # vs. corporation) and strip whitespace and normalize on letter casing.
  #
  def normalize_name
    self[:FirstName]     = self.FirstName.blank?     ? nil : self.FirstName.strip.upcase
    self[:MiddleInitial] = self.MiddleInitial.blank? ? nil : self.MiddleInitial.strip.upcase
    self[:LastName]      = self.LastName.blank?      ? nil : self.LastName.strip.upcase
    self[:Suffix]        = self.Suffix.blank?        ? nil : self.Suffix.strip.upcase
    if self.IndCorp.blank? or self.IndCorp =~ /individual$/i
      self.name = [
        (self.LastName.blank? ? nil : "#{self.LastName},"),
         self.FirstName,
         self.MiddleInitial,
         self.Suffix
      ].reject { |p| p.blank? }.join(" ")
      self.name.chomp!(",")
    else
      self.name = self.FirstName
    end
  end
end
