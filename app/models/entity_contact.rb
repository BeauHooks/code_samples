class EntityContact < ActiveRecord::Base
  self.table_name  = "tblEntityContacts"
  self.primary_key = "ContactID"

  before_save :create_inactive, :update_primary
  after_save :update_entity_last_modified, :update_convienence_fields

  attr_defaults :Address  => { :default => "", :if => :blank? }
  attr_defaults :Address2 => { :default => "", :if => :blank? }
  attr_defaults :City     => { :default => "", :if => :blank? }
  attr_defaults :State    => { :default => "", :if => :blank? }
  attr_defaults :Contact  => { :default => "", :if => :blank? }

  belongs_to :entity,                             foreign_key: "EntityID",       primary_key: "EntityID"
  belongs_to :source,     class_name: "Entity",   foreign_key: "SourceEntityID", primary_key: "EntityID"
  belongs_to :entered_by, class_name: "Employee", foreign_key: "EnteredBy",      primary_key: "ID"

  # TODO: Move this into a concern
  STATES = {
    "Alabama"              => "AL" ,
    "Alaska"               => "AK" ,
    "Arizona"              => "AZ" ,
    "Arkansas"             => "AR" ,
    "California"           => "CA" ,
    "Colorado"             => "CO" ,
    "Connecticut"          => "CT" ,
    "Delaware"             => "DE" ,
    "District Of Columbia" => "DC" ,
    "Florida"              => "FL" ,
    "Georgia"              => "GA" ,
    "Hawaii"               => "HI" ,
    "Idaho"                => "ID" ,
    "Illinois"             => "IL" ,
    "Indiana"              => "IN" ,
    "Iowa"                 => "IA" ,
    "Kansas"               => "KS" ,
    "Kentucky"             => "KY" ,
    "Louisiana"            => "LA" ,
    "Maine"                => "ME" ,
    "Maryland"             => "MD" ,
    "Massachusetts"        => "MA" ,
    "Michigan"             => "MI" ,
    "Minnesota"            => "MN" ,
    "Mississippi"          => "MS" ,
    "Missouri"             => "MO" ,
    "Montana"              => "MT" ,
    "Nebraska"             => "NE" ,
    "Nevada"               => "NV" ,
    "New Hampshire"        => "NH" ,
    "New Jersey"           => "NJ" ,
    "New Mexico"           => "NM" ,
    "New York"             => "NY" ,
    "North Carolina"       => "NC" ,
    "North Dakota"         => "ND" ,
    "Ohio"                 => "OH" ,
    "Oklahoma"             => "OK" ,
    "Oregon"               => "OR" ,
    "Pennsylvania"         => "PA" ,
    "Rhode Island"         => "RI" ,
    "South Carolina"       => "SC" ,
    "South Dakota"         => "SD" ,
    "Tennessee"            => "TN" ,
    "Texas"                => "TX" ,
    "Utah"                 => "UT" ,
    "Vermont"              => "VT" ,
    "Virginia"             => "VA" ,
    "Washington"           => "WA" ,
    "West Virginia"        => "WV" ,
    "Wisconsin"            => "WI" ,
    "Wyoming"              => "WY"
  }

  # Apparently, a record may first be categorized by the ContactType field,
  # which is one of "ADDRESS", "CONTACT", "WIRE" or NULL (where "WIRE" and
  # NULL are extremely rare).
  #
  CATEGORIES = {
    :address => "ADDRESS",
    :contact => "CONTACT",
    :wire    => "WIRE"
  }

  # Once categorized, each contact may be further organized by type, using
  # either the Description or ContactDesc field (depending on the category).
  #
  TYPES = {
    :address => {
      :field => :Description,
      :types => {
        :mailing     => "Mailing Address",
        :office_addr => "Office", # disambiguate from :office below (under :contact category)
        :primary     => "Primary Residence",
        :secondary   => "Secondary Residence",
        :prior       => "Prior Residence",
        :investment  => "Investment Property"
      }
    },
    :contact => {
      :field => :ContactDesc,
      :types => {
        :cell   => "Cell",
        :email  => "Email",
        :fax    => "Fax",
        :home   => "Home",
        :office => "Office",
        :web    => "WebSite"
      }
    }
  }

  scope :active_addresses, -> { where(:ContactType => CATEGORIES[:address], :IsActive => -1, :IsInactive => 0) }
  scope :addresses,        -> { where(:ContactType => CATEGORIES[:address]) }
  scope :active_contacts,  -> { where(:ContactType => CATEGORIES[:contact], :IsActive => -1, :IsInactive => 0) }
  scope :contacts,         -> { where(:ContactType => CATEGORIES[:contact]) }
  scope :wires,            -> { where(:ContactType => CATEGORIES[:wire   ]    ) }
  scope :unknowns,         -> { where(:ContactType.not_in => CATEGORIES.values) }

  scope :active_emails, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => TYPES[:contact][:types][:email],
      :IsActive => -1,
      :IsInactive => 0
    )
  }
  scope :emails, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => TYPES[:contact][:types][:email]
    )
  }

  scope :active_fax, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => [:fax].map { |k| TYPES[:contact][:types][k] },
      :IsActive => -1,
      :IsInactive => 0
    )
  }
  scope :fax, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => [:fax].map { |k| TYPES[:contact][:types][k] }
    )
  }

  scope :active_phones_callable, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => [:cell, :home, :office].map { |k| TYPES[:contact][:types][k] },
      :IsActive => -1,
      :IsInactive => 0
    )
  }
  scope :phones_callable, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => [:cell, :home, :office].map { |k| TYPES[:contact][:types][k] }
    )
  }

  scope :active_phones, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => [:cell, :fax, :home, :office].map { |k| TYPES[:contact][:types][k] },
      :IsActive => -1,
      :IsInactive => 0
    )
  }
  scope :phones, lambda {
    where(
      :ContactType => CATEGORIES[:contact],
      TYPES[:contact][:field] => [:cell, :fax, :home, :office].map { |k| TYPES[:contact][:types][k] }
    )
  }

  def self.primary_address
    active_addresses.find_by_Primary(-1) || EntityContact.new
  end

  def self.primary_email
    active_emails.find_by_Primary(-1) || EntityContact.new
  end

  def self.primary_fax
    active_fax.find_by_Primary(-1) || EntityContact.new
  end

  def self.primary_phone
    active_phones_callable.find_by_Primary(-1) || EntityContact.new
  end

  def self.contact_types
    TYPES[:contact][:types].each do |t, v|
      [t,v]
    end
  end

  def contact_types
    entity = self.entity
    types = []
    TYPES[:contact][:types].each do |t,v|
      next if t == :email && entity.IndCorp != "Individual"
      types << [t,v]
    end
    types
  end

  def self.address_types
    TYPES[:address][:types].each do |t,v|
      [t,v]
    end
  end

  # Quick access to all records either of the provided category or, if a
  # specific type w/in a category is provided, all records of only that type
  #
  def self.categorized_as(category_or_type)
    case category_or_type
    when :address
      addresses
    when :contact
      contacts
    when :wire
      wires
    else
      category = TYPES.find { |k, v| v[:types].has_key?(category_or_type) }
      return unknowns unless category
      where(
        :ContactType => CATEGORIES[category],
        TYPES[category][:field] => pattern
      )
    end
  end

  #
  # Find all addresses that include the provided pattern
  #
  def self.address_includes(pattern)
    pattern = "#{pattern}%" unless pattern.last  == "%"
    pattern = "%#{pattern}" unless pattern.first == "%"
    addresses.where(:Address.matches % pattern | :Address2.matches % pattern)
  end

  #
  # Find all phone numbers that include the provided pattern
  #
  def self.phone_includes(pattern)
    if pattern !~ /%/ and pattern.gsub(/[^\d]/, '') =~ /(\d)?(\d{3})?(\d{3})?(\d{4})$/
      pattern = "%" + [$1, $2, $3, $4].compact.join("%") + "%"
    end
    phones.where(:Contact.matches => pattern)
  end

  #
  # Find all email addresses that include the provided pattern
  #
  def self.email_includes(pattern)
    pattern = "#{pattern}%" unless pattern.last  == "%"
    pattern = "%#{pattern}" unless pattern.first == "%"
    emails.where(:Contact.matches => pattern)
  end

  def line
    if self.ContactType == "ADDRESS"
      address = ""
      address = "#{self.Address}" if self.Address.to_s != ""
      address != "" ? address += " #{self.Address2}" : address += "#{self.Address2}"
      address += ", " if address != ""
      address += "#{self.City}" if self.City.to_s != ""
      address += ", #{self.State}" if self.State.to_s != ""
      address += " #{self.Zip}" if self.Zip.to_s != ""

      return self.description + " - " + address
    else
      return self.description + " - " + self.Contact.to_s
    end
  end

  #
  # Get the best description of the contact info
  #
  def description
    if self.Description != nil && self.Description != ""
      return self.Description
    elsif self.ContactDesc != nil && self.ContactDesc != ""
      return self.ContactDesc
    else
      return self.ContactType
    end
  end

  def type
    if self.ContactDesc != nil && self.ContactDesc != ""
      return self.ContactDesc
    else
      return self.ContactType
    end
  end

  def modify_date
  if self.EnteredDT != nil
    return self.EnteredDT.to_formatted_s(:date_only)
  else
    return ""
  end
  end

  def modify_user
    unless self.EnteredBy.nil?
      self.entered_by.FullName
    end
  end

  def address
    addr = []
    addr << self.Address unless self.Address.nil?
    addr << self.Address2 unless self.Address2.nil?
    addr << self.City unless self.City.nil?
    addr << self.abbreviation
    addr << self.Zip unless self.Zip.nil?
    addr
  end

  def abbreviation
    STATES[self.State.titleize]
  end

  def inactive
    self.update_column("IsActive", 0)
    self.update_column("IsInactive", -1)
  end

  def active
    self.update_column("IsActive", -1)
    self.update_column("IsInactive", 0)
  end

  def remove_primary
    self.update_column("Primary", 0)
    self.update_column("IsPrimary", 0)
  end

  def add_primary
    self.update_column("Primary", -1)
    self.update_column("IsPrimary", -1)
  end

  def primary?
    self.Primary == -1 && self.IsPrimary == -1
  end

  def inactive?
    self.IsActive == 0 && self.IsInactive == -1
  end

  def active?
    self.IsActive == -1 && self.IsInactive == 0
  end

  private

  def create_inactive
    changes = self.changed
    if !(["Contact", "Address", "Address2", "City", "State", "Zip"] & changes).to_a.empty? && !self.new_record?
      new_contact = self.dup
      self.reload
      self_is_primary = self.primary?
      self.IsActive = 0
      self.IsInactive = -1
      self.Primary = 0
      self.IsPrimary = 0
      new_contact.save
      new_contact.active
      new_contact.add_primary if self_is_primary
    end
  end

  def update_primary
    if self.ContactID != nil && self.IsPrimary_changed?
      if self.ContactType.downcase == "contact"
        if ["home", "office", "cell"].include?(self.ContactDesc.downcase)
          contacts = self.entity.entity_contacts.phones_callable.where("ContactID != #{self.ContactID} AND (IsPrimary = -1 OR 'Primary' = -1)")
          contacts.each { |c| c.remove_primary }
        elsif self.ContactDesc.downcase == "fax"
          contacts = self.entity.entity_contacts.fax.where("ContactID != #{self.ContactID} AND (IsPrimary = -1 OR 'Primary' = -1)")
          contacts.each { |c| c.remove_primary }
        elsif self.ContactDesc.downcase == "email"
          contacts = self.entity.entity_contacts.emails.where("ContactID != #{self.ContactID} AND (IsPrimary = -1 OR 'Primary' = -1)")
          contacts.each { |c| c.remove_primary }
        end
      else self.ContactType.downcase == "address"
        contacts = self.entity.entity_contacts.addresses.where("ContactID != #{self.ContactID} AND (IsPrimary = -1 OR 'Primary' = -1)")
        contacts.each { |c| c.remove_primary }
      end
    end
  end

  def update_convienence_fields
    entity = self.entity
    if self.IsPrimary == -1 && self.active?
      if self.ContactType.downcase == "contact"
        if ["home", "office", "cell"].include?(self.ContactDesc.downcase)
          entity.primary_phone_number = "#{self.ContactDesc}: #{self.Contact}"
          case self.ContactDesc.downcase
          when "home"
            entity.HomePhone = self.Contact
          when "office"
            entity.WorkPhone = self.Contact
          when "cell"
            entity.CellPhone = self.Contact
          end
        elsif self.ContactDesc.downcase == "fax"
          entity.FaxNum = self.Contact
        elsif self.ContactDesc.downcase == "email"
          entity.Email = self.Contact
        end
      elsif self.ContactType.downcase == "address"
        entity.primary_address = self.Address
        entity.primary_city = self.City
        entity.primary_state = self.State
      end
      entity.save
    else
      if self.ContactType.downcase == "contact"
        if ["home", "office", "cell"].include?(self.ContactDesc.downcase)
          entity.primary_phone_number = "" if entity.primary_phone_number == "#{self.ContactDesc}: #{self.Contact}"
          case self.ContactDesc.downcase
          when "home"
            entity.HomePhone = "" if entity.HomePhone == self.Contact
          when "office"
            entity.WorkPhone = "" if entity.WorkPhone == self.Contact
          when "cell"
            entity.CellPhone = "" if entity.CellPhone == self.Contact
          end
        elsif self.ContactDesc.downcase == "fax"
          entity.FaxNum = "" if entity.FaxNum == self.Contact
        elsif self.ContactDesc.downcase == "email"
          entity.Email = "" if entity.Email == self.Contact
        end
      elsif self.ContactType.downcase == "address"
        entity.primary_address = "" if entity.primary_address == self.Address
        entity.primary_city = "" if entity.primary_city == self.City
        entity.primary_state = '' if entity.primary_state == self.State
      end
      entity.save
    end
  end

  def update_entity_last_modified
    self.entity.update_last_modified
  end
end
