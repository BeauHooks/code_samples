class Employee < ActiveRecord::Base
  require 'net/ldap'
  require 'yaml'
  self.table_name  = "tblEmployees"
  self.primary_key = "ID"

  default_scope conditions: ["ID NOT IN (190, 119, 95, 157, 327)"], order: 'FullName ASC'
  scope :active, where((:Active == true) & (:IsTitle != true)) # Actual Employees (NOT title companies) who are currently Active

  COMPANY_TAG = Regexp.new("<!--@company(-->(.*?)<!--company)?@-->", "i") # company name placeholder
  DOMAIN_TAG  = Regexp.new("<!--@domain(-->(.*?)<!--domain)?@-->",   "i") # company domain name placeholder
  WEBURL_TAG  = Regexp.new("<!--@weburl(-->(.*?)<!--weburl)?@-->",   "i") # company website placeholder
  LOGO_TAG    = Regexp.new("<!--@logo(-->(.*?)<!--logo)?@-->",       "i") # company logo url placeholder
  PHOTO_TAG   = Regexp.new("<!--@photo(-->(.*?)<!--photo)?@-->",     "i") # employee photo url placeholder
  EMAIL_DOMAINS = {
    101 => "sutc.com",
    102 => "terratitle.com",
    103 => "sutc.com",
    104 => "mesquitetitle.com",
    105 => "signingservices.net",
    106 => "sutc.com",
    108 => "equityescrow.com",
    110 => "defaults4u.com",
    111 => "recons4u.com",
    112 => "titlemanagers.com",
    116 => "mesquitetitle.com"
  }

  has_many   :employee_rolodexes,                                                   primary_key: "ID",        foreign_key: "EmployeeID"
  has_many   :entities,                           through: :employee_rolodexes
  has_many   :file_employees,                                                       primary_key: "ID",        foreign_key: "EmployeeID",        order: "FileID"
  has_many   :supervisees,                        class_name: "Employee",           primary_key: "ID",        foreign_key: "Supervisor",        order: "ID"
  has_many   :marketees,                          class_name: "Employee",           primary_key: "ID",        foreign_key: "Marketer",          order: "ID"
  has_many   :files_as_closer,                    class_name: "FileInfo",           primary_key: "ID",        foreign_key: "CloserAssigned",    order: "CompanyID, FileID"
  has_many   :cpls,                          class_name: "ClosingProtectionLetter", primary_key: "ID",        foreign_key: "closer_id"
  has_many   :files_as_searcher,                  class_name: "FileInfo",           primary_key: "ID",        foreign_key: "SearcherAssigned",  order: "CompanyID, FileID"
  has_many   :files_as_assistant,                 class_name: "FileInfo",           primary_key: "ID",        foreign_key: "AssistantAssigned", order: "CompanyID, FileID"
  has_many   :messages
  has_many   :recipients
  has_many   :rate_calculations,                                                    primary_key: "ID",                                          order: "created_at"
  has_many   :web_communications,                                                   primary_key: "ID",        foreign_key: "EmployeeID",        order: "FileID, DummyTime"
  belongs_to :employee_position,                  class_name: "EmployeePosition",   primary_key: "ID",        foreign_key: "Position"
  belongs_to :supervisor,                         class_name: "Employee",           primary_key: "ID",        foreign_key: "Supervisor"
  belongs_to :marketer,                           class_name: "Employee",           primary_key: "ID",        foreign_key: "Marketer"
  belongs_to :department,                                                           primary_key: "ID",        foreign_key: "Department"
  belongs_to :office,                                                               primary_key: "ID",        foreign_key: "Office"
  belongs_to :company,                                                              primary_key: "CompanyID", foreign_key: "Company"
  has_one    :user,                                                                 primary_key: "ID",        foreign_key: "employee_id"

  # Employee Action-Tracking Relationships
  has_many   :entered_entities,                   class_name: "Entity",             primary_key: "ID",        foreign_key: "EnteredBy",          order: "EnteredDT"
  has_many   :reviewed_entities,                  class_name: "Entity",             primary_key: "ID",        foreign_key: "ReviewedBy",         order: "ReviewedDT"
  has_many   :entered_entity_affiliations,        class_name: "EntityAffiliation",  primary_key: "ID",        foreign_key: "EnteredBy",          order: "EnteredDT"
  has_many   :entered_entity_contacts,            class_name: "EntityContact",      primary_key: "ID",        foreign_key: "EnteredBy",          order: "EnteredDT"
  has_many   :entered_entity_permissions,         class_name: "EntityPermission",   primary_key: "ID",        foreign_key: "EnteredBy",          order: "EnteredDT"
  has_many   :taken_entity_notes,                 class_name: "EntityNote",         primary_key: "ID",        foreign_key: "TakenBy",            order: "NoteDT"
  has_many   :tickled_entity_notes,               class_name: "EntityNote",         primary_key: "ID",        foreign_key: "TickleEmployeeID",   order: "TickleDate"
  has_many   :deactivated_entity_permissions,     class_name: "EntityPermission",   primary_key: "ID",        foreign_key: "InactiveBy",         order: "InactiveDT"
  has_many   :created_entity_rules,               class_name: "EntityRule",         primary_key: "ID",        foreign_key: "CreatedBy",          order: "RuleDT"
  has_many   :entered_entity_signatures,          class_name: "EntitySignature",    primary_key: "ID",        foreign_key: "EnteredBy",          order: "EnteredDT"
  has_many   :modified_file_endorsements,         class_name: "FileEndorsement",    primary_key: "ID",        foreign_key: "ModifiedBy",         order: "ModifiedDT"
  has_many   :approved_file_endorsements,         class_name: "FileEndorsement",    primary_key: "ID",        foreign_key: "ApprovedBy",         order: "ApprovedDT"
  has_many   :created_file_endorsements,          class_name: "FileEndorsement",    primary_key: "ID",        foreign_key: "CreatedBy",          order: "CreatedDT"
  has_many   :private_file_images,                class_name: "FileImage",          primary_key: "ID",        foreign_key: "PrivateBy",          order: "PrivateDT"
  has_many   :entered_file_images,                class_name: "FileImage",          primary_key: "ID",        foreign_key: "EnteredBy",          order: "ImageDate"
  has_many   :entered_file_notes,                 class_name: "FileNote",           primary_key: "ID",        foreign_key: "EnteredBy",          order: "NoteDT"
  has_many   :tickled_file_notes,                 class_name: "FileNote",           primary_key: "ID",        foreign_key: "TickleEmployeeID",   order: "TickleDate"
  has_many   :completed_file_notes,               class_name: "FileNote",           primary_key: "ID",        foreign_key: "CompletedBy",        order: "DoneDate"
  has_many   :searched_file_properties,           class_name: "FileProperty",       primary_key: "ID",        foreign_key: "SearchedBy",         order: "SearchedDT"
  has_many   :typed_file_products,                class_name: "FileProduct",        primary_key: "ID",        foreign_key: "TypedBy",            order: "TypedDT"
  has_many   :reviewed_file_products,             class_name: "FileProduct",        primary_key: "ID",        foreign_key: "ReviewedBy",         order: "ReviewedDT"
  has_many   :approved_file_products,             class_name: "FileProduct",        primary_key: "ID",        foreign_key: "ApprovedBy",         order: "ApprovedDT"
  has_many   :delivered_file_products,            class_name: "FileProduct",        primary_key: "ID",        foreign_key: "DeliveredBy",        order: "DeliveredDT"
  has_many   :approved_policy_forms,              class_name: "PolicyForm",         primary_key: "ID",        foreign_key: "ApprovedBy",         order: "ApprovedDT"
  has_many   :edited_policy_forms,                class_name: "PolicyForm",         primary_key: "ID",        foreign_key: "EditedBy",           order: "EditedDT"
  has_many   :typed_policy_forms,                 class_name: "PolicyForm",         primary_key: "ID",        foreign_key: "TypedBy",            order: "TypedDT"
  has_many   :created_remit_batches,              class_name: "RemitBatch",         primary_key: "ID",        foreign_key: "BatchCreatedBy",     order: "BatchCreatedDT"
  has_many   :reviewed_remit_batches,             class_name: "RemitBatch",         primary_key: "ID",        foreign_key: "ReviewedBy",         order: "ReviewDT"
  has_many   :approved_remit_batches,             class_name: "RemitBatch",         primary_key: "ID",        foreign_key: "ApprovedBy",         order: "ApprovedDT"
  has_many   :sent_remit_batches,                 class_name: "RemitBatch",         primary_key: "ID",        foreign_key: "BatchSentBy",        order: "BatchSentDT"
  has_many   :entered_deliveries,                 class_name: "Delivery",           primary_key: "ID",        foreign_key: "EnteredBy",          order: "EnteredDT"
  has_many   :from_deliveries,                    class_name: "Delivery",           primary_key: "ID",        foreign_key: "FromEmployeeID",     order: "SentDT"
  has_many   :modified_schedule_a_old_histories,  class_name: "ScheduleAHistory",   primary_key: "ID",        foreign_key: "ModifiedBy",         order: "ModifiedDT"

  # Employee Action-Tracking Specifically for version tracking stuff
  has_many   :created_versioned_sets,             class_name: "VersionedSet",       primary_key: "ID",        foreign_key: "created_by",         order: "created_at"
  has_many   :updated_versioned_sets,             class_name: "VersionedSet",       primary_key: "ID",        foreign_key: "updated_by",         order: "updated_at"
  has_many   :created_versions,                   class_name: "Version",            primary_key: "ID",        foreign_key: "created_by",         order: "created_at"
  has_many   :updated_versions,                   class_name: "Version",            primary_key: "ID",        foreign_key: "updated_by",         order: "updated_at"
  has_many   :created_regions,                    class_name: "Region",             primary_key: "ID",        foreign_key: "created_by",         order: "created_at"
  has_many   :updated_regions,                    class_name: "Region",             primary_key: "ID",        foreign_key: "updated_by",         order: "updated_at"

  # Employee Action-Tracking Specifically for Files
  has_many   :order_taken_for_files,              class_name: "FileInfo",           primary_key: "ID",        foreign_key: "OrderTakenBy",       order: "OrderTakenDT"
  has_many   :date_down_entered_for_files,        class_name: "FileInfo",           primary_key: "ID",        foreign_key: "DateDownEnteredBy",  order: "DateDownEntered"
  has_many   :dated_down_files,                   class_name: "FileInfo",           primary_key: "ID",        foreign_key: "DatedDownBy",        order: "DatedDown"
  has_many   :pr_reviewd_for_files,               class_name: "FileInfo",           primary_key: "ID",        foreign_key: "PRReviewedBy",       order: "PRReviewed"
  has_many   :pr_proof_for_files,                 class_name: "FileInfo",           primary_key: "ID",        foreign_key: "PRProofBy",          order: "PRProofDT"
  has_many   :pr_approved_for_files,              class_name: "FileInfo",           primary_key: "ID",        foreign_key: "PRApprovedBy",       order: "PRApproved"
  has_many   :pr_out_for_files,                   class_name: "FileInfo",           primary_key: "ID",        foreign_key: "PROutBY",            order: "CompanyID, FileID"
  has_many   :reviewed_files,                     class_name: "FileInfo",           primary_key: "ID",        foreign_key: "FileReviewedBy",     order: "FileReviewed"
  has_many   :policy_approved_for_files,          class_name: "FileInfo",           primary_key: "ID",        foreign_key: "PolApprovedBy",      order: "PolApproved"
  has_many   :funded_files,                       class_name: "FileInfo",           primary_key: "ID",        foreign_key: "FundedBy",           order: "Funded"
  has_many   :recorded_files,                     class_name: "FileInfo",           primary_key: "ID",        foreign_key: "RecordedBy",         order: "Recorded"
  has_many   :ok_to_disburse_approved_for_files,  class_name: "FileInfo",           primary_key: "ID",        foreign_key: "DisbOKToApproveBy",  order: "DisbOkToApproveDT"
  has_many   :disbursed_files,                    class_name: "FileInfo",           primary_key: "ID",        foreign_key: "DisbursedBy",        order: "Disbursed"
  has_many   :balanced_files,                     class_name: "FileInfo",           primary_key: "ID",        foreign_key: "BalancedBy",         order: "Balanced"
  has_many   :locked_files,                       class_name: "FileInfo",           primary_key: "ID",        foreign_key: "LockedBy",           order: "CompanyID, FileID"
  has_many   :rpt_closed_for_files,               class_name: "FileInfo",           primary_key: "ID",        foreign_key: "RptClosedBy",        order: "RptClosedDT"

  def self.closers(company=nil, view_locked_files=false)
    if company.nil?
      if view_locked_files
        self.find(:all, conditions: ["Active != 0 AND ID NOT IN (190, 119, 95, 157, 327)"], order: "FullName ASC")
      else
        self.find(:all, conditions: ["Active != 0 AND Department = 2 AND ID NOT IN (190, 119, 95, 157, 327) OR ID = 5"], order: "FullName ASC")
      end
    else
      if view_locked_files
        self.find(:all, conditions: ["Active != 0 AND Company = #{company} AND ID NOT IN (190, 119, 95, 157, 327)"], order: "FullName ASC")
      else
        self.find(:all, conditions: ["Active != 0 AND Company = #{company} AND Department = 2 AND ID NOT IN (190, 119, 95, 157, 327) OR ID = 5 "], order: "FullName ASC")
      end
    end
  end

  def self.no_user
    all = Employee.where("Active != 0 AND IsTitle = 0 AND ID NOT IN (190, 119, 95, 157, 327)")
    users = Employee.find(:all, joins: [:user], conditions: "tblEmployees.Active != 0 AND tblEmployees.IsTitle = 0")
    return (all - users)
  end

  # This is a smart employee finder. It returns nil if it cannot find and/or
  # load the employee specified.
  #
  # If you pass an existing Employee instance as the 'value' then it will
  # simply be returned. Otherwise, it will try to use the value as an employee
  # ID number, and then as a unique name. Only if it can uniquely identify the
  # employee will it return one.
  #
  def self.smart_find(value)
    return value if value.is_a?(Employee)
    return nil   if value.nil?
    if value.to_s =~ /^\d+$/
      return (self.find(value.to_i) rescue nil)
    end
    set    = []
    conds  = ["SSN LIKE ?", "Initials LIKE ?  ", "SOUNDEX(ComputerLoginName) LIKE SOUNDEX(?)", "SOUNDEX(FullName) LIKE SOUNDEX(?)", "SOUNDEX(Email) LIKE SOUNDEX(?)"]
    value  = "%#{value.to_s.strip}%"
    filter = lambda do |c|
      r = Employee.find(:all, :conditions => [c, value]).to_a
      return nil if r.empty?
      if set.empty?
        set = r
      else
        set &= r
      end
      set.uniq!
      return set
      nil
    end
    result = filter.call(conds.shift)
    result = filter.call(conds.shift) until result or conds.empty?
    result
  end

  #
  # Standard password "encryption" used to obscure passwords in records
  #
  def self.encrypt(plaintext)
    return nil unless plaintext.is_a?(String)
    result = ""
    plaintext.chars { |c| result << (c.ord + 3).chr }
    result
  end

  def self.decrypt(ciphertext)
    return nil unless ciphertext.is_a?(String)
    result = ""
    ciphertext.chars { |c| result << (c.ord - 3).chr }
    result
  end

  def email_sudoer?
    self.ACViewPrivateEmail?
  end

  # The employee's password in plaintext. The query method has an optional ldap
  # boolean parameter that, if true, instead of simply returning the decrypted
  # password (the default) will basically pass the decrypted password through
  # the #ldap_auth method (with insensitive set to true) and return the result.
  #
  # The second variation can be used to quickly tell if the user's filetrak
  # password is the same as their LDAP/Windows/E-Mail password and, if so, get
  # the case-sensitive-correct version of it. Thus, this second version may
  # return nil even though the employee's password field IS set. This will
  # happen when the employee/filetrak password differs from the LDAP/E-Mail one
  # by more than upper/lower-case differences.
  #
  def password(ldap = false)
    p = Employee.decrypt(self[:MyPassword])
    return p unless ldap
    ldap_auth(p, true)
  end
  def password=(plaintext)
    if plaintext.nil?
      self[:MyPassword] = nil # unset password
    elsif plaintext.is_a?(String)
      raise ArgumentError, "blank passwords not allowed" if plaintext.blank?
      self[:MyPassword] = Employee.encrypt(plaintext.upcase)
    else
      raise ArgumentError, "invalid type (#{plaintext.class}) for password"
    end
  end

  # Check to see if the provided password is valid for the current user
  def auth(password)
    return false if self[:MyPassword].blank?
    Employee.encrypt(password.upcase) == self[:MyPassword].upcase
  end

  # See if the provided password is the valid, LDAP password for the current
  # user or not. You may either do a case-sensitive or insensitive check of the
  # password. The default is to be case sensitive. Pass true for insensitive for
  # a case-insensitive test.
  #
  # NOTE: internally, all authentication attempts are case-sensitive. This
  #       method basically does a brute-force authentication if insensitive is
  #       true, trying all case combinations until all have been tried or a
  #       successful match is made.
  #
  # If the password doesn't match, nil is returned. Otherwise, the successfully
  # matched password is returned (string). For case-sensitive calls, this will
  # always be the same as the provided password. For case-insensitive calls,
  # the returned password is the one who's upper/lower-case variations actually
  # worked an may differ (in case) from the provided password.
  #
  def ldap_auth(password, insensitive = false)
    user   = nil
    filter = Net::LDAP::Filter.eq("objectClass", "tmiEmployee") &
             Net::LDAP::Filter.eq("tmiEmployeeId", self.id.to_s)
    ldap   = Employee.ldap_connection
    ldap.search(
      :base          => "ou=Users, #{ldap.base}",
      :filter        => filter,
      :attributes    => %w{ dn },
      :return_result => false
    ) do |entry|
      user = entry.dn
    end
    return nil unless user
    ldap.auth(user, password)
    return password.dup if ldap.bind
    return nil unless insensitive
    p = password.downcase
    while p
      ldap.auth(user, p)
      return p if ldap.bind
      p = Employee.next_password(p)
    end
    nil
  end

  # Retrieve a data hash of the information about this employee from the LDAP
  # database, if there is matching information. If no LDAP entry matches then an
  # empty hash is returned.
  #
  # After the first call to this method, the resulting hash is cached. To force
  # a refresh, just pass true to the optional refresh parameter.
  #
  # The information (possibly) available for a given employee from the LDAP
  # database includes:
  #
  #   :username   => Username used to log in (to mail and windows): "john"
  #   :name       => Full display name: "John Doe"
  #   :email      => Primary local/delivery email address: "john@domain.tld"
  #   :full       => Full display email: "John Doe <john@domain.tld>"
  #   :uid        => Unix user ID number
  #   :gid        => Unix group ID number
  #
  def ldap(refresh = false)
    return @ldap unless refresh or @ldap.nil?
    @ldap  = {}
    ldap   = Employee.ldap_connection
    filter = Net::LDAP::Filter.eq("objectClass", "tmiEmployee") &
             Net::LDAP::Filter.eq("tmiEmployeeId", self.id.to_s)
    ldap.search(
      :base          => "ou=Users, #{ldap.base}",
      :filter        => filter,
      :attributes    => %w{ uid mailDestination displayName uidNumber gidNumber },
      :return_result => false
    ) do |entry|
      @ldap[:username] = entry.uid.first
      @ldap[:name]     = entry.displayName.first     rescue nil
      @ldap[:email]    = entry.mailDestination.first rescue nil
      @ldap[:full]     = "#{@ldap[:name]} <#{@ldap[:email]}>" if @ldap[:name] and @ldap[:email]
      @ldap[:uid]      = entry.uidNumber.first.to_i  rescue nil
      @ldap[:gid]      = entry.gidNumber.first.to_i  rescue nil
    end
    @ldap
  end

  def position
    self.employee_position != nil ? self.employee_position.PositionName : "NULL"
  end

  def has_permission?(permission, option={})
    user = self.user
    if user != nil
      user.has_permission?(permission, option)
    else
      self.position == "Closer" && self.Company == option[:company].to_i
    end
  end

  def belongs_to_index(file)
    file.file_employees.find(:all, conditions: ["EmployeeID = #{current_user.employee_id} AND is_active != 0"]).size > 0
  end

  # Get the "full" email address (Bob Jones <bob@dot.com>)
  def full_email
    return nil if self.Email.blank? or self.Email !~ /^[a-z0-9!%._=+-]+@[a-z0-9.-]+$/i
    return self.Email if self.FullName.blank?
    "#{self.FullName} <#{self.Email}>"
  end

  # Formatted access to the Direct Phone field
  def direct_phone
    return '' if self.DirectPhone.blank?
    tmp = self.DirectPhone.gsub(/[^\d]+/, '')
    return '' unless tmp =~ /^(1?(\d{3}))?(\d{3})(\d{4})$/
    tmp = "#{$3}-#{$4}"
    $2.blank? ? tmp : "(#{$2}) #{tmp}"
  end

  def direct_phone=(val)
    val = val.to_s.gsub(/[^\d]+/, '')
    if val =~ /^(1?(\d{3}))?(\d{3})(\d{4})$/
      self.DirectPhone = "#{$2}#{$3}#{$4}"
    else
      self.DirectPhone = ''
    end
  end

  def direct_fax
    return '' if self.DirectFax.blank?
    tmp = self.DirectFax.gsub(/[^\d]+/, '')
    return '' unless tmp =~ /^(1?(\d{3}))?(\d{3})(\d{4})$/
    tmp = "#{$3}-#{$4}"
    $2.blank? ? tmp : "(#{$2}) #{tmp}"
  end

  # Get the signature field for this employee (unprocessed text)
  def signature(company = nil)
    result = self.Signature
    result.blank? ? default_signature(company) : result.dup
  end

  # If the Signature appears to be plain text, returns that. Otherwise gets
  # the default signature (which is always plain-text)
  #
  def text_signature(company = nil)
    result = self.Signature
    (result.blank? or result =~ /^\s*</im) ? default_signature(company) : result.dup
  end

  # Get a plain-text version of the employee's __default__ signature. This
  # method is designed to be robust, never triggering an exception! It traps
  # everything (hard to debug)! It also tries to return as much signature data
  # as it can.
  #
  def default_signature(company = nil)
    result       = ""
    company    ||= self.company
    name         = self.FullName         rescue nil
    company_name = company.CompanyName   rescue nil
    phone        = self.direct_phone     rescue nil
    extension    = self.PhoneExtension   rescue nil
    fax          = self.direct_fax       rescue nil
    weburl       = company.WebDomainName rescue nil
    result      << "#{name}\n"                 unless name.blank?
    result      << "#{company_name}\n"         unless company_name.blank?
    result      << "Phone:     #{phone}\n"     unless phone.blank?
    result      << "Extension: #{extension}\n" unless extension.blank?
    result      << "Fax:       #{fax}\n"       unless fax.blank?
    result      << "Web Site:  #{weburl}\n"    unless weburl.blank?
    result
  rescue
    ""
  end

  # This will return the signature (either text or html) with any embedded
  # "special" tags replaced (based on the options and/or company). If you don't
  # provide any company (either directly or as :company in an options hash) then
  # the employee's default company is used. So, you can call this with no args
  # to get their signature processed for their default company. Or, you can pass
  # a Company instance to get a version of their signature processed for that
  # company instead. Finally, you can instead pass an options hash with the
  # following settings which override the default company or a provided company:
  #
  #   :company => provide a Company instance in an options hash
  #   :name    => provide an alternate company name
  #   :domain  => provide an alternate company email domain
  #   :weburl  => provide an alternate company web url
  #   :logo    => provide full path to alternate company logo image
  #   :photo   => provide full path to alternate employee photo image
  #   :attach  => prepend "cid:" to paths replaced for logo and photo tags for
  #               use when inserting signature in an email (and the images will
  #               need to be attached); if true, prepending is all that is done;
  #               if an array, the unmunged (before the prepending) image paths
  #               for any/all such embedded special tags will be added to the
  #               provided array (so the caller can the "attach" these images)
  #   :force   => either :html or :text if provided, force one of these two
  #               forms to be provided; if the user's signature it a text one
  #               :html is passed, the plain text signature will be wrapped in
  #               <pre></pre> tags to make it HTML; if the user's signature is
  #               HTML and :text is passed then the users #default_signature
  #               (which is always plain text) will be returned instead
  #
  def processed_signature(options_or_company = nil, options = nil)
    raise ArgumentError, "invalid type for options (#{options.class}), expected hash" unless options.nil? or options.is_a?(Hash)
    raise ArgumentError, "invalid type for first parameter: #{options_or_company.class}; expected Company or hash" unless
      options_or_company.nil? or options_or_company.is_a?(Hash) or options_or_company.is_a?(Company)
    options ||= {}
    options   = options_or_company.merge(options) if options_or_company.is_a?(Hash)
    company   = self.company
    company   = options[:company]  if options[:company].is_a?(Company)
    company   = options_or_company if options_or_company.is_a?(Company)
    attach    = options[:attach]
    attach    = [] if attach and !attach.is_a?(Array) # provide/use dummy array if we got boolean
    raise ArgumentError, "no default company for employee and no valid company provided" unless
      company.is_a?(Company)

    # Get the unprocessed signature and data for any "special" tags we may have
    result = signature(company)
    result = default_signature(company) if result =~ /^\s*</im and options[:force] == :text
    raise "no valid signature set (and none generated)" unless result.is_a?(String) and !result.blank?
    if result =~ /^\s*</im # HTML signature: remove outer <html> and <body> tags
      result = $1 if result =~ /<html[^>]*>(.*)<\/html[^>]*>/im
      result = $1 if result =~ /<body[^>]*>(.*)<\/body[^>]*>/im
    elsif options[:force] == :html
      result = "<pre>\n#{result}\n</pre>"
    end
    name   =                options[:name]   || company.CompanyName       rescue nil
    domain =                options[:domain] || EMAIL_DOMAINS[company.id] rescue nil
    weburl =                options[:weburl] || company.WebDomainName     rescue nil
    logo   = DriveMap.posix(options[:logo]   || company.CompanyLogo)      rescue nil
    photo  = DriveMap.posix(options[:photo]  || self.EmpPhoto      )      rescue nil

    # Process all the "special" tags, validating for each one that we have the
    # required data if it's used.
    #
    if result =~ COMPANY_TAG
      raise ArgumentError, "no available company name and/or an invalid/blank one provided (#{name.class})" unless
        name.is_a?(String) and !name.blank?
      result.gsub!(COMPANY_TAG, name)
    end
    if result =~ DOMAIN_TAG
      raise ArgumentError, "no available company email domain and/or an invalid/blank one provided (#{domain.class})" unless
        domain.is_a?(String) and !domain.blank?
      result.gsub!(DOMAIN_TAG, domain)
    end
    if result =~ WEBURL_TAG
      raise ArgumentError, "no available company web url and/or an invalid/blank one provided (#{weburl.class})" unless
        weburl.is_a?(String) and !weburl.blank?
      result.gsub!(WEBURL_TAG, weburl)
    end
    if result =~ LOGO_TAG
      raise ArgumentError, "no available company logo and/or an invalid/blank path provided (#{logo.class})" unless
        logo.is_a?(String) and File.file?(logo)
      attach << logo.dup if attach # modifies provided attachment array in-place
      result.gsub!(LOGO_TAG, attach ? "cid:#{logo}" : logo)
    end
    if result =~ PHOTO_TAG
      raise ArgumentError, "no available employee photo and/or an invalid/blank path provided (#{photo.class})" unless
        photo.is_a?(String) and File.file?(photo)
      attach << photo.dup if attach # modifies provided attachment array in-place
      result.gsub!(PHOTO_TAG, attach ? "cid:#{photo}" : photo)
    end
    result
  end

  # Recieves a web request parameters collection and is expected to return
  # a value that is valid for a :conditions clause of an ActiveRecord find
  # that is searching for Message instances (filtering on these search
  # conditions) pertaining to this employee...
  #
  def email_search_conditions(entity, mode, me, limited, params)
    merge_conditions = lambda do |existing, *current|
      if existing.blank?
        current.flatten
      else
        tmp  = existing.first
        tmp  = "(#{tmp})" unless tmp =~ /^\s*\(.*\)\s*$/
        tmp  = [tmp + " AND (#{current.flatten.first})", *existing[1..-1]]
        [tmp, *current.flatten[1..-1]].flatten
      end
    end
    result = nil
    search = params[:search].to_s.strip

    # Search based on our current mode tab and sudoer settings...
    case mode
    when 'inbox'
      result = merge_conditions.call(result, 'messages.from LIKE ?',      "%#{search}%") unless search.blank?
      result = merge_conditions.call(result, 'recipients.employee_id = ?', self.id     ) unless self.email_sudoer? and !me
    when 'sent'
      result = merge_conditions.call(result, 'recipients.address LIKE ?', "%#{search}%") unless search.blank?
      result = merge_conditions.call(result, 'messages.employee_id = ?',   self.id     ) unless self.email_sudoer? and !me
    when 'all'
      search = "%#{search}%" unless search.blank?
      result = merge_conditions.call(result,
        'messages.from LIKE ? OR recipients.address LIKE ?',
        search, search
        ) unless search.blank?
      result = merge_conditions.call(result,
        'messages.employee_id = ? OR recipients.employee_id = ?',
        self.id, self.id
        ) unless self.email_sudoer? and !me
    when 'advanced'
      search = "%#{search}%" unless search.blank?
      result = merge_conditions.call(result,
        'messages.from LIKE ? OR recipients.address LIKE ?',
        search, search
        ) unless search.blank?
      result = merge_conditions.call(result,
        'messages.employee_id = ? OR recipients.employee_id = ?',
        self.id, self.id
        ) unless self.email_sudoer? and !me
    end

    # Limit result to just those involving specified entity...
    if entity and limited
      result = merge_conditions.call(result,
        'messages.entity_id = ? OR recipients.entity_id = ?',
        entity.id, entity.id
        )
    end
    result
  end

  # Given the provided system (LDAP) username, lookup the user and then load the
  # associated Employee record if the LDAP entry exists (and links to an
  # employee record).
  #
  def self.find_by_ldap_username(username)
    result = nil
    ldap   = ldap_connection
    filter = Net::LDAP::Filter.eq("objectClass", "tmiEmployee") &
             Net::LDAP::Filter.eq("uid", username)
    ldap.search(
      :base          => "ou=Users, #{ldap.base}",
      :filter        => filter,
      :attributes    => "tmiEmployeeId",
      :return_result => false
    ) do |entry|
      result = find(entry.tmiEmployeeId.first)
    end
    result
  end

  # Given the provided system (LDAP) user's displayName, lookup the user and
  # then load the associated Employee record if the LDAP entry exists (and links
  # to an employee record).
  #
  # NOTE: returns nil if multiple LDAP records are found to match
  #
  def self.find_by_ldap_display_name(name)
    result = nil
    multi  = false
    ldap   = ldap_connection
    filter = Net::LDAP::Filter.eq("objectClass", "tmiEmployee") &
             Net::LDAP::Filter.eq("displayName", name)
    ldap.search(
      :base          => "ou=Users, #{ldap.base}",
      :filter        => filter,
      :attributes    => "tmiEmployeeId",
      :return_result => false
    ) do |entry|
      result = find(entry.tmiEmployeeId.first)
      if result
        return nil if multi
        multi = true
      end
    end
    result
  end

  # This finds ALL employees to whom the provided address delivers. If the
  # optional parameter "aliases" is left at its default of true then all users
  # to whom the address, possibly an alias address, ultimately delivers will be
  # returned in an array. Otherwise, if "aliases" is false (or nil) then an
  # array with at most one matching employee will be returned since the address
  # will only be looked up as a local address (that can belong to at most one
  # employee).
  #
  # If the address is invalid or otherwise doesn't belong to a system user that
  # is an actual employee (objectClass includes tmiEmployee) then an empty array
  # is returned.
  #
  def self.find_by_ldap_email(addr, aliases = true)
    if aliases
      ldap_usernames_from_addr(addr)
    else
      [ldap_username_from_local_addr(addr)].compact
    end.map do |username|
      find_by_ldap_username(username)
    end.uniq
  end

  # Get a pre-configured Net::LDAP instance based on config/ldap.yml config
  def self.ldap_connection
    config = YAML.load_file(LDAP)
    Net::LDAP.new(
      :host => config["server"],
      :port => config["port"].to_i,
      :base => config["base"]
    )
  end

  # This returns any system user usernames from the LDAP database that would be
  # ultimate recipients for an email destined to addr. If the address doesn't
  # belong to a system user or eventually alias to one, or is otherwise invalid
  # then an empty array is returned.
  #
  def self.ldap_usernames_from_addr(addr)
    result = ldap_username_from_local_addr(addr)
    (ldap_usernames_from_alias_addr(addr) << result).compact.uniq
  end

  # Given the provided email address, look it up to see if it is a valid local
  # delivery email address for a system user. If so, return the system username
  # for the user that corresponds with the address.
  #
  def self.ldap_username_from_local_addr(addr)
    result = nil
    ldap   = ldap_connection
    filter = Net::LDAP::Filter.eq("objectClass", "mailUser") &
             Net::LDAP::Filter.eq("mailDestination", addr)
    ldap.search(
      :base          => "ou=Users, #{ldap.base}",
      :filter        => filter,
      :attributes    => "uid",
      :return_result => false
    ) do |entry|
      result = entry.uid.first
    end
    result
  end

  # Given an alias email address, return the LDAP (windows logon) usernames that
  # correspond (own) the utlimate delivery addresses for the alias. If the alias
  # address doesn't exist (is invalid) or doesn't eventually deliver to a local
  # (or terminal) address belonging to a system user then an empty array is
  # returned. Otherwise, an array with one or more usernames is returned.
  #
  # NOTE: an empty array is returned if you pass in a "local" address instead of
  #       an alias. For a local addrss, use: ldap_username_from_local_addr
  #
  def self.ldap_usernames_from_alias_addr(addr)
    ldap_email_alias_recipients(addr).map do |addr|
      ldap_username_from_local_addr(addr)
    end.sort.uniq
  end

  # For the given alias email address, return the complete list of "local" email
  # addresses that this alias ultimately references (possibly through several
  # intermediary aliases). If the given address isn't an alias address then an
  # empty array is returned (including if you pass a "local" or "terminal" email
  # address instead of an alias address).
  #
  # The address must be in its pure form: user@domain.tld
  #
  def self.ldap_email_alias_recipients(addr)
    result = []
    tried  = []
    queue  = [addr.downcase]
    until queue.empty?
      tried    << queue.first
      next unless queue.shift =~ /^(.+)@(.+)$/
      user   = $1
      domain = $2
      ldap_next_email_alias_recipients(user, domain).each do |addr|
        addr.downcase!
        if ldap_username_from_local_addr(addr)
          result << addr
        elsif !tried.include?(addr) and !queue.include?(addr)
          queue << addr
        end
      end
    end
    result.sort.uniq
  end

  # For the given alias email address, return the complete list of alias email
  # addresses that ultimately deliver to the provided email address (may itself
  # be an alias, remote address, or local delivery address). If no aliases in
  # the system result in delivery to this address the an empty array is
  # returned.
  #
  # The address must be in its pure form: user@domain.tld
  #
  def self.ldap_email_alias_sources(addr)
    result = []
    tried  = []
    queue  = [addr.downcase]
    until queue.empty?
      tried << queue.first
      ldap_next_email_alias_sources(queue.shift).each do |addr|
        addr.downcase!
        result << addr
        if !tried.include?(addr) and !queue.include?(addr)
          queue << addr
        end
      end
    end
    result.sort.uniq
  end

  # For a given user@domain (w/user and domain parts passed as separate
  # parameters), retrieve the next-level address(es) this address is an alias
  # for. This DOES NOT do a recursive lookup, it just returns the next-level
  # reciepient list of email addresses which may be local addresses or alias
  # addresses.
  #
  # If the address provided (user and domain) doesn't exist as an alias then
  # an empty array is returned. This includes "local" or terminal addresses:
  # they aren't aliases so they don't return anything!
  #
  def self.ldap_next_email_alias_recipients(user, domain)
    result = []
    ldap   = ldap_connection
    filter = Net::LDAP::Filter.eq("objectClass", "mailAliasEntry") &
             Net::LDAP::Filter.eq("mailAliasSource", "#{user}@#{domain}")
    ldap.search(
      :base          => "mailDomain=#{domain}, ou=Email, #{ldap.base}",
      :filter        => filter,
      :attributes    => "mailAliasDestinations",
      :return_result => false
    ) do |entry|
      result += entry.mailAliasDestinations
    end
    result
  end

  # Retrieves a list of alias addresses that directly deliver to the provided
  # email address (user@domain). If none match, an empty array is returned.
  #
  def self.ldap_next_email_alias_sources(addr)
    result = []
    ldap   = ldap_connection
    filter = Net::LDAP::Filter.eq("objectClass", "mailAliasEntry") &
             Net::LDAP::Filter.eq("mailAliasDestinations", addr)
    ldap_mail_domains.each do |domain|
      ldap.search(
        :base          => "mailDomain=#{domain}, ou=Email, #{ldap.base}",
        :filter        => filter,
        :attributes    => "mailAliasSource",
        :return_result => false
      ) do |entry|
        result << entry.mailAliasSource.first
      end
    end
    result.sort.uniq
  end

  # Get a list of all our email domains
  def self.ldap_mail_domains
    result = []
    ldap   = ldap_connection
    ldap.search(
      :base           => "ou=Email, #{ldap.base}",
      :filter         => Net::LDAP::Filter.eq("objectClass", "mailDomainEntry"),
      :attributes     => "mailDomain",
      :return_results => false
    ) do |entry|
      result << entry.mailDomain.first
    end
    result.sort.uniq
  end

  # Given a version of a password, returns the next "version" or distinct
  # combination of lower/upper-case characters and returns it. Returns nil if
  # the provided password is the "last" possible combination. In order for this
  # to work, the first call should pass a pwd with all lowercase letters. Each
  # successive call should pass the result of the prior call. When nil is
  # is finally returned, the pwd passed was the last case combination.
  #
  # This is used by #ldap_auth to brute-force case combinations to simulate
  # case-insensitive authentication (and to determine the correct-case of a
  # given password).
  #
  # NOTE: given a password with either no alpha character or where all alpha
  #       characters are upper-case, this always returns nil as said password
  #       is defined as the "terminal" of final combination
  #
  def self.next_password(pwd)
    return nil unless pwd =~ /[a-z]/
    done   = false
    result = ""
    pwd.chars.each do |c|
      if done or c !~ /[a-z]/i
        result << c
      elsif c =~ /[A-Z]/
        result << c.downcase
      else
        result << c.upcase
        done = true
      end
    end
    result
  end
end
