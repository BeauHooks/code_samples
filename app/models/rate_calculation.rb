class RateCalculation < ActiveRecord::Base
  establish_connection :rate_calc

  belongs_to :company,               :primary_key => "CompanyID"
  belongs_to :employee,              :primary_key => "ID"
  belongs_to :index,                 :primary_key => "FileID", :foreign_key => "file_info_id"
  belongs_to :vendor_trak_file_info, :primary_key => "FileID"
  belongs_to :underwriter,           :primary_key => "ID"
  belongs_to :web_communication,     :primary_key => "WebComID"
  belongs_to :calc_version, :foreign_key => :version_id, :primary_key => :id

  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(CalcVersion) ? v.id : v) } } }

  DEFAULT_POLICY_1_TYPE = "Home Owners Policy".freeze
  DEFAULT_POLICY_2_TYPE = "Loan Policy".freeze
  DEFAULT_COMPANY_ID    =  101
  DEFAULT_FILE_INFO_ID  =    0
  DEFAULT_EMPLOYEE_ID   =    0

  # Smart constructor to create new rate calculation instances with default
  # values already loaded for any required but unset values
  #
  def initialize(*args, &block)
    #
    # Set custom class vars here for documentation as much as anything
    #
    @defaults_loaded = false
    @calculator      = nil
    @table           = nil
    #
    # Call parent constructor set set attributes according to params provided
    #
    super(*args, &block)
    #
    # Load default values for any core data that wasn't provided
    #
    self.load_defaults
  end

  def self.initialize_from_file(file_id, employee_id, product_name, mode, options={})
    file = Index.where("FileID = #{file_id}").first
    raise "No valid file to initialize from" unless !file.nil?
    RateCalculation.create(
      underwriter_id: options[:underwriter_id] || file.company.default_underwriter,
      company_id:     file.Company,
      employee_id:    employee_id,
      file_info_id:   file.FileID,
      product_name:   product_name,
      mode:           mode
    )
  end

  # Used to initiaze the state of the object with defaults for any of the core
  # fields that aren't already set
  #
  def load_defaults
    return if @defaults_loaded
    #
    # Set any unset fields to their default values
    #
    self.company_id    ||= DEFAULT_COMPANY_ID
    self.file_info_id  ||= DEFAULT_COMPANY_ID * 10 + DEFAULT_FILE_INFO_ID
    self.employee_id   ||= DEFAULT_FILE_INFO_ID
    self.mode          ||= "default"
    self.product_name  ||= ""
    self.policy_1_type ||= DEFAULT_POLICY_1_TYPE
    self.policy_2_type ||= DEFAULT_POLICY_2_TYPE
    self.underwriter   ||= self.company.default_underwriter if self.company
    self.underwriter   ||= Underwriter.first(:conditions => { :IsActive => true }, :order => :Underwriter)
    @defaults_loaded     = true
  end

  # Load the RateLibrary instance for this class if necessary and return this
  # instances associated calculator
  #
  def calculator
    return @calculator if @calculator

    # Ensure all core values at least have default values
    self.load_defaults

    # Set parameters that determine which version of the rate library to load
    file   = self.index rescue nil
    date   = nil
    date   = file.PROut     if file and file.PROut
    date   = file.PolicyOut if file and file.PolicyOut
    date ||= Date.today

    # Determine the version to load if not already determined
    self.calc_version ||= RateLibrary.determine_version(
      :date     => date,
      :file     => file,
      :employee => self.employee_id,
      :company  => self.company_id
    )

    # HACK: just re-run the search for a correct version using today's date
    #       if no version could be found...
    self.calc_version ||= RateLibrary.determine_version(
      :date     => Date.today,
      :file     => file,
      :employee => self.employee_id,
      :company  => self.company_id
    )
    raise "No valid version for the rate calculator could be determined" unless self.calc_version

    # Load the rate calculation library for this version
    @calculator = RateLibrary.load_version(self.calc_version)
    raise "Version #{self.version_id} of the RateLibrary couldn't be loaded" unless @calculator
    @calculator
  end

  # Get a pre-computed table of rates (calculating them now, if necessary. This
  # returns an array with one entry per underwriter. Each entry is a hash with
  # the following keys:
  #   :underwriter_id      (integer)         Underwriter's ID
  #   :underwriter_name    (string)          Underwriter's display name
  #   :manual              (nil or string)   Relative URL to Underwriter's rate manual
  #   :enabled             (boolean)         Whether this underwriter is enabled or not
  #   :selected            (boolean)         Whether this is the selected underwriter or not
  #   :amount_[X]          (nil or decimal)  X is 1, 2, or 3: Calculated amount
  #   :no_split_amount_[X] (nil or decimal)  X is 1, 2, or 3: Calculated "no split" amount
  #   :display_[X]         (string or nil)   Display string that is a combination of the
  #                                          above two amounts (set to "N/A" if they are
  #                                          both nil)
  def table
    self.calculate! unless @table
    @table
  end

  # This method attempts to update the calculator's state by loading values for
  # various variables from the associated file's data
  def import!
    self.load_defaults

    # This method only works in the following modes. If in one of the valid
    # modes then this object is invalid if we don't have an attached file.
    return unless %w{ pr hud policy_1 policy_2 }.include?(self.mode)
    file = self.index
    raise "Invalid state for given mode (#{self.mode}); no file!"         if file.nil?
    raise "Invalid state for given mode (#{self.mode}); no product name!" if self.product_name.blank?
    display_file_id = self.file_info_id.to_s[3..-1].to_i

    # Determine our "primary" and "secondary" product names to use for
    # schedule a lookup
    case self.mode
    when "pr"
      pri_product_name = self.product_name
      sec_product_name = self.product_name
    when "hud"
      pri_product_name = "PR"
      sec_product_name = "PR"
    when "policy_1"
      pri_product_name = self.product_name
      sec_product_name = self.alternate_policy_product_name
    when "policy_2"
      pri_product_name = self.alternate_policy_product_name
      sec_product_name = self.product_name
    end

    # Lookup up values for the file (from schedule a)
    file_product = FileProduct.where(
      file_id:          self.file_info_id,
      product_type_id:  ProductType.where("name = '#{pri_product_name}'").first.id,
      is_active:        -1,
    ).first
    pri_product_sched = sec_product_sched = ScheduleA.where("file_product_id = #{file_product.id}").first
    policy_1, policy_2 = file_product.schedule_a.policies[0..1]

    if self.mode == "pr" or self.mode == "hud"
      self.policy_1_type    = policy_1.type unless policy_1.nil?
      self.policy_2_type    = policy_2.type unless policy_2.nil?
      self.policy_1_product = pri_product_name # uses smart attribute accessors below
      self.policy_2_product = sec_product_name # to set base product name...
    else # "policy_1" or "policy_2" mode
      self.policy_1_product = pri_product_name
      self.policy_2_product = sec_product_name
      self.policy_1_type    = self.policy_1_product.sub(/~.*\z/, '') rescue nil
      self.policy_2_type    = self.policy_2_product.sub(/~.*\z/, '') rescue nil
      sec_product_name      = self.policy_2_type if self.mode == "policy_1"
      pri_product_name      = self.policy_1_type if self.mode == "policy_2"
    end

    unless policy_1.nil?
      self.policy_1_amount        = policy_1.amount
      self.policy_1_is_developer  = policy_1.use_developer_rate?
    end

     unless policy_2.nil?
      self.policy_2_amount        = policy_2.amount
      self.policy_2_is_developer  = policy_2.use_developer_rate?
      self.policy_2_is_refinance  = policy_2.is_refinance?
    end

    self.calculator # Used to load/set our "version"
  end

  # Allow you to read the dynamically updated policy 1 and 2 product names
  # (using the current value of the policy type) while allowing you to set the
  # base product name (of the same) where it will ignore any appended policy
  # type information (anything after the first ~ if any).
  #
  # If in one of the two policy modes, the attribute accessor act normally.
  def policy_1_product
    return self['policy_1_product'] if self.policy_1_type.blank? or %w{policy_1 policy_2}.include?(self.mode)
    "#{self['policy_1_product']}~#{self.policy_1_type}"
  end

  def policy_1_product=(val)
    val = val.sub(/~.*\z/, '') if val.is_a?(String) and not %w{policy_1 policy_2}.include?(self.mode)
    self['policy_1_product'] = val
  end

  def policy_2_product
    return self['policy_2_product'] if self.policy_2_type.blank? or %w{policy_1 policy_2}.include?(self.mode)
    "#{self['policy_2_product']}~#{self.policy_2_type}"
  end

  def policy_2_product=(val)
    val = val.sub(/~.*\z/, '') if val.is_a?(String) and not %w{policy_1 policy_2}.include?(self.mode)
    self['policy_2_product'] = val
  end

  # When in one of the policy modes, this is used to look up the "product name"
  # for "the other policy". The other policy is the 2nd one when in policy_1
  # mode and is the first one when in policy_2 mode.
  def alternate_policy_product_name

    # This method only make's sense if called from policy_X modes
    raise "Called in invalid mode: #{self.mode}." unless %w{ policy_1 policy_2 }.include?(self.mode)
    not_like = ["PR%", "PRIOR%", "%WRITE%", "%REPORT%"].map { |e| "ProductName NOT LIKE '#{e}'" }.join(" AND ")
    others = self.index.file_products.all(
      :conditions => ["IsActive = -1 AND ProductName <> ? AND #{not_like}", self.product_name]
      )
    return "" unless others.length > 0
    preferred = others.first.ProductName
    if preferred =~ /~/
      others.each do |o|
        if o.ProductName !~ /~/
          preferred = o.ProductName
          break
        end
      end
    end
    preferred
  end

  # Allow formatted access to all our date fields
  def policy_1_prior_date_display=(val)
    self.policy_1_prior_date = val.from_date
  end

  def policy_2_prior_date_display=(val)
    self.policy_2_prior_date = val.from_date
  end

  def policy_3_prior_date_display=(val)
    self.policy_3_prior_date = val.from_date
  end

  def policy_1_prior_date_display
    self.policy_1_prior_date.to_s(:std)
  end

  def policy_2_prior_date_display
    self.policy_2_prior_date.to_s(:std)
  end

  def policy_3_prior_date_display
    self.policy_3_prior_date.to_s(:std)
  end

  # Allow formatted access to all our currency fields
  def policy_1_amount_display=(val)
    self.policy_1_amount = val.from_currency
  end

  def policy_2_amount_display=(val)
    self.policy_2_amount = val.from_currency
  end

  def policy_3_amount_display=(val)
    self.policy_3_amount = val.from_currency
  end

  def policy_1_prior_amount_display=(val)
    self.policy_1_prior_amount = val.from_currency
  end

  def policy_2_prior_amount_display=(val)
    self.policy_2_prior_amount = val.from_currency
  end

  def policy_3_prior_amount_display=(val)
    self.policy_3_prior_amount = val.from_currency
  end

  def policy_1_hourly_rate_display=(val)
    self.policy_1_hourly_rate = val.from_currency
  end

  def policy_2_hourly_rate_display=(val)
    self.policy_2_hourly_rate = val.from_currency
  end

  def policy_1_hourly_amount_display=(val)
    self.policy_1_hourly_amount = val.from_currency
  end

  def policy_2_hourly_amount_display=(val)
    self.policy_2_hourly_amount = val.from_currency
  end

  def policy_1_amount_display
    self.policy_1_amount.to_currency(:blank => true)
  end

  def policy_2_amount_display
    self.policy_2_amount.to_currency(:blank => true)
  end

  def policy_3_amount_display
    self.policy_3_amount.to_currency(:blank => true)
  end

  def policy_1_prior_amount_display
    self.policy_1_prior_amount.to_currency(:blank => true)
  end

  def policy_2_prior_amount_display
    self.policy_2_prior_amount.to_currency(:blank => true)
  end

  def policy_3_prior_amount_display
    self.policy_3_prior_amount.to_currency(:blank => true)
  end

  # Get the legal list of policy types valid for a policy_X_type field
  def policy_types(policy_number)
    bases = case policy_number
      when 1 then %w{ OWNER REPORT }
      when 2 then %w{ ALTA  REPORT }
      when 3 then %w{ ALTA         }
      else
        raise ArgumentError, "Invalid value for policy_number parameter"
      end
    PolicyType.versioned(self.version_id).all(
      :conditions => { :Advanced => 0 },
      :group      => "PolicyDescription, AllowReIssue, AllowBetterReissue, BasedOn",
      :having     => bases.map { |b| "BasedOn = '#{b}'" }.join(" OR ")
      )
  end

  # Return the list of FileEndorsements that are attached to our associated
  # file number and specifically to the product of policy_number X
  def policy_endorsements(policy_number)
    order   = "updated_at DESC"

    case self.mode
    when "pr"
      pri_product_name = self.product_name
      sec_product_name = self.product_name
    when "hud"
      pri_product_name = "PR"
      sec_product_name = "PR"
    when "policy_1"
      pri_product_name = self.product_name
      sec_product_name = self.alternate_policy_product_name
    when "policy_2"
      pri_product_name = self.alternate_policy_product_name
      sec_product_name = self.product_name
    end

    file_product = FileProduct.find(:all, joins: [:product_type], conditions: ["file_id = #{self.file_info_id} AND product_types.name = '#{policy_number == 1 ? pri_product_name : sec_product_name}'"]).first
    if !file_product.nil?
      policy       = file_product.schedule_a.policies.find(:all, joins: [:policy_type], conditions: ["tblPolicyTypes.PolicyType = '#{policy_number == 1 ? self.policy_1_product : self.policy_2_product}'"]).first rescue nil
      results      = policy.policy_endorsements rescue []
    else
      results = PolicyEndorsement.where(policy_id: 0)
    end
    results.reject do |e|
      next true unless e.endorsement
      e.endorsement.Underwriter != self.underwriter_id or e.endorsement.version_id != self.version_id
    end
  end

  # Replicates logic in FileInfo.endorsement_premiums_total but in so doing
  # allows us to deal with FileEndorsements who's file number doesn't refer
  # to an actual file (such as our default file number of 1010)
  def policy_endorsements_total(policy_number, underwriter_id)
    data = {}
    if self.table != []
      self.table.each do |t|
        t[:underwriter_id] == underwriter_id ? data = t : nil
      end
    end
    result = 0.0
    amount = (policy_number == 1 ? data[:amount_1] : data[:amount_2]) || 0.0
    policy_endorsements(policy_number).reject { |e| e.endorsement.nil? }.each do |e|
      e_id    = e.id
      e_id    = e.endorsement.id
      u_tmp   = e.endorsement.underwriter
      result += self.calculator.endorsement_premium(u_tmp, e_id, amount)
    end
    result
  end

  # Helper calculation method used to determine the amount for any specific,
  # given endorsement (that may or may not actually be attached to a file,
  # allowing us to use this on the default file number 1010)
  #
  def policy_endorsement_amount(policy_number, endorsement, underwriter_id) policy_1_type_instance
    data = {}
    if self.table != []
      self.table.each do |t|
        t[:underwriter_id] == underwriter_id ? data = t : nil
      end
    end
    policy_type  = (policy_number == 1 ? policy_1_type_instance : policy_2_type_instance)
    amount       = (policy_number == 1 ? data[:amount_1] : data[:amount_2]) || 0.0
    e_id = endorsement.id
    self.calculator.endorsement_premium(self.underwriter, e_id, amount)
  end

  # Remove the specified FileEndorsement from our associated file. Returns a
  # boolean indicating whether the endorsement was successfully located, was
  # found to be attached to our file, and then removed.
  #
  # NOTE: policy_number may be a numeric string and needs to be converted!
  #
  def remove_endorsement!(policy_number, endorsement_id)
    policy_number = policy_number.to_i
    endorsement   = PolicyEndorsement.find(endorsement_id)
    return false unless endorsement and [1, 2].include?(policy_number)
    endorsement.delete
    true
  end

  # Add a FileEndorsement to the database (if it doesn't already exist) for
  # our currently configured file number
  #
  def add_endorsement!(policy_number, endorsement_id)
    calculator
    raise ArgumentError, "Invalid value for policy_number: #{policy_number}" unless [1, 2].include?(policy_number)
    endorsement = Endorsement.versioned(self.version_id).find(endorsement_id)
    raise ArgumentError, "Invalid endorsement id: unable to find match: #{endorsement_id} (version: #{self.version_id})" unless endorsement

    case self.mode
    when "pr"
      pri_product_name = self.product_name
      sec_product_name = self.product_name
    when "hud"
      pri_product_name = "PR"
      sec_product_name = "PR"
    when "policy_1"
      pri_product_name = self.product_name
      sec_product_name = self.alternate_policy_product_name
    when "policy_2"
      pri_product_name = self.alternate_policy_product_name
      sec_product_name = self.product_name
    end

    file_product = FileProduct.find(:all, joins: [:product_type], conditions: ["file_id = #{self.file_info_id} AND product_types.name = '#{policy_number == 1 ? pri_product_name : sec_product_name}'"]).first
    # Am I working with a real product?
    if !file_product.nil?
      policy       = file_product.schedule_a.policies.where(:sort_order => policy_number).first
      policy_id    = policy.id
    else
      policy_id = 0
    end
    endorsement.policy_endorsements.create(
      :endorsement_id => endorsement.EndorsementID,
      :policy_id      => policy_id,
      :amount         => policy_endorsement_amount(policy_number, endorsement, file_product.schedule_a.underwriter_id),
      :updated_by     => self.employee_id,
      :updated_at     => Time.now,
      :created_by     => self.employee_id,
      :created_at     => Time.now
    )
  end

  # Add a set of FileEndorsements to the database (if they don't already
  # exist) for our currently configured file number
  #
  def add_endorsement_group!(policy_number, group_id)
    group_id = group_id.to_i
    raise ArgumentError, "Invalid value for policy_number: #{policy_number}" unless [1, 2].include?(policy_number)
    raise ArgumentError, "Invalid group_id number: #{group_id}"              unless self.calculator::CALC_ENDORSEMENTS.keys.include?(group_id)
    endorsements = Endorsement.versioned(self.version_id).all(
      :conditions => {
        :Endorsement => self.calculator::CALC_ENDORSEMENTS[group_id][:match],
        :Underwriter => self.underwriter_id
      }
    )
    endorsements.each { |e| self.add_endorsement!(policy_number, e.id) }
  end

  # Shortcut methods to get PolicyType instance that corresponds to a policy's
  # currently selected policy type description string...
  #
  def policy_1_type_instance
    self.underwriter.policy_types.versioned(self.version_id).find_by_PolicyDescription(self.policy_1_type)
  end
  def policy_2_type_instance
    self.underwriter.policy_types.versioned(self.version_id).find_by_PolicyDescription(self.policy_2_type)
  end
  def policy_3_type_instance
    self.underwriter.policy_types.versioned(self.version_id).find_by_PolicyDescription(self.policy_3_type)
  end

  # Utility method used to save the current rate calculation state info to the
  # associated file's state
  #
  def save_to_file!
    # Don't do anything if we're in a default, unknown, or "calculation" mode
    # Also don't do anything unless we've got an actual file selected and can
    # find a ScheduleA entry that matches the file and product name...
    #
    file = self.index rescue nil
    return unless %w{ pr hud policy_1 policy_2 }.include?(self.mode) and file
    file_product = file.file_products.where("policy_type_id = #{ProductType.where("name = '#{self.product_name}'").first.id} AND is_active != 0").first
    sched_a = file_product.schedule_a
    raise "Unable to find schedule A entry for File ##{self.file_info_id}, Product '#{self.product_name}'" unless sched_a
    sched_a.updated_by = self.employee_id

    # Calculate endorsement amounts and text-list
    endorsement_amount = self.policy_endorsements_total(1) + self.policy_endorsements_total(2)
    endorsement_list   = self.policy_endorsements(1).map { |e| e.ShortName ? e.ShortName : e.EndorsementName }
    endorsement_list  += self.policy_endorsements(2).map { |e| e.ShortName ? e.ShortName : e.EndorsementName }
    endorsement_list   = endorsement_list.join("/")

    # Calculate the two rates that we need
    rate_1 = nil
    rate_2 = nil
    owner_basic_rate = nil
    alta_basic_rate  = nil
    if %w{ pr hud policy_1 }.include?(self.mode) and self.policy_1_amount and self.policy_1_type
      rate_1 = self.calculator.calculate_rate(
        self.underwriter, 1,
        self.policy_1_amount,
        self.policy_1_type,
        self.policy_1_is_developer?,
        false,
        self.policy_1_prior_amount,
        self.policy_1_prior_date,
        self.policy_2_amount,
        self.policy_2_type
      )
      owner_basic_rate = self.calculator.basic_owner_rate(self.underwriter, self.policy_1_amount)
    end
    if %w{ pr hud policy_2 }.include?(self.mode) and self.policy_2_amount and self.policy_2_type
      rate_2 = self.calculator.calculate_rate(
        self.underwriter, 2,
        self.policy_2_amount,
        self.policy_2_type,
        self.policy_2_is_developer?,
        self.policy_2_is_refinance?,
        self.policy_2_prior_amount,
        self.policy_2_prior_date,
        self.policy_1_amount,
        self.policy_1_type
      )
      alta_basic_rate = self.calculator.basic_owner_rate(self.underwriter, self.policy_2_amount)
    end

    # Update sales price?
    unless self.policy_1_amount.blank? or not %w{ pr hud policy_1 }.include?(self.mode)
      file.SalesPrice = self.policy_1_amount
      file.save!
    end

    # Update loan amount?
    unless self.policy_2_amount.blank? or not %w{ pr hud policy_2 }.include?(self.mode)
      file.LoanAmount = self.policy_2_amount
      file.save!
    end

    # Set values that all modes have in common...
    p_amount = self.policy_1_prior_amount
    p_date   = self.policy_1_prior_date
    is_dev   = self.policy_1_is_developer?
    if self.mode == "policy_2"
      p_amount = self.policy_2_prior_amount
      p_date   = self.policy_2_prior_date
      is_dev   = self.policy_2_is_developer?
    end
    if self.mode != "policy_1" and not endorsement_list.blank?
      sched_a.Endorsements   = endorsement_list
      sched_a.EndorsementAmt = endorsement_amount
    end
    sched_a.underwriter_id          = self.underwriter_id
    sched_a.policies[0].entry_reissue_amount = p_amount if p_amount
    sched_a.policies[0].entry_reissue_date     = p_date
    sched_a.policies[0].use_developer_rate       = is_dev

    # Set values specific to the two "policy" modes
    if %w{ policy_1 policy_2 }.include?(self.mode)
      premium = rate_1
      amount  = self.policy_1_amount
      if self.mode == "policy_2"
        sched_a.policies[1].is_refinance         = self.policy_2_is_refinance?
        premium                       = rate_2[:rate]     if rate_2
        amount                        = self.policy_2_amount
      end
    end

    # Set values specific to "hud" and "pr" modes
    if %w{ hud pr }.include?(self.mode)
      sched_a.policies[0].premium        = rate_1            if rate_1
      sched_a.policies[1].premium        = rate_2[:rate]     if rate_2
      sched_a.policies[0].amount          = self.policy_1_amount
      sched_a.policies[1].amount           = self.policy_2_amount
      sched_a.policies[0].policy_type_id  = PolicyType.where("PolicyDescription = '#{self.policy_1_type}'").first.ID
      sched_a.policies[1].policy_type_id  = PolicyType.where("PolicyDescription = '#{self.policy_2_type}'").first.ID
      sched_a.policies[1].entry_reissue_amount = self.policy_2_prior_amount
      sched_a.policies[1].entry_reissue_date     = self.policy_2_prior_date
      sched_a.policies[1].use_developer_rate  = self.policy_2_is_developer?
      sched_a.policies[1].is_refinance          = self.policy_2_is_refinance?
    end
    sched_a.save!
  end

  # Clean up any/all FileEndorsements that are attached to the file that aren't
  # approved or remitted, so that only those matching the specified version and
  # underwriter remain. If an endorsement is to be removed, see if there is an
  # equivalent one that matches the underwriter/version and add it if it
  # doesn't already exist
  #
  def cleanup_endorsements!(policy_number)
    case self.mode
    when "pr"
      pri_product_name = self.product_name
      sec_product_name = self.product_name
    when "hud"
      pri_product_name = "PR"
      sec_product_name = "PR"
    when "policy_1"
      pri_product_name = self.product_name
      sec_product_name = self.alternate_policy_product_name
    when "policy_2"
      pri_product_name = self.alternate_policy_product_name
      sec_product_name = self.product_name
    end

    file_product = FileProduct.find(:all, joins: [:product_type], conditions: ["file_id = #{self.file_info_id} AND product_types.name = '#{policy_number == 1 ? pri_product_name : sec_product_name}'"]).first
    if !file_product.nil?
      policy_id    = file_product.schedule_a.policies.where(:sort_order => policy_number).first.id
      endorsements = file_product.schedule_a.policy_endorsements.where(:policy_id => policy_id)
    else
      endorsements = PolicyEndorsement.where(policy_id: 0)
      policy_id    = 0
    end
    remove       = []
    endorsements.each do |fe|
      next if fe.approved_at or fe.remitted_at
      e = fe.endorsement rescue nil
      Rails.logger.info "  Attached to a valid Endorsement? #{e ? 'yes' : 'no'}"
      remove << fe unless e # remove invalid ones (they have no ref. Endorsement)
      next         unless e
      next             if e.Underwriter == self.underwriter_id and e.version_id == self.version_id
      remove << fe
      equiv = Endorsement.find_by_Endorsement_and_Underwriter_and_version_id(e.Endorsement, self.underwriter_id, self.version_id)
      unless equiv.nil? or endorsements.map { |f| f.endorsement_id }.include?(equiv.id)

        # Add a new, equivalent endorsement...
        PolicyEndorsement.create(
          :endorsement_id => equiv.EndorsementID,
          :policy_id      => policy_id,
          :amount         => policy_endorsement_amount(policy_number, equiv, file_product.schedule_a.underwriter_id),
          :updated_by     => self.employee_id,
          :updated_at     => Time.now,
          :created_by     => self.employee_id,
          :created_at     => Time.now
        )
      else
        remove << fe
      end
    end

    # Clean out our FileEndorsements flagged for removal
    remove.each { |fe| fe.delete }
  end

  # Utility method to calculate a complete pre-computed table of all rates.
  # The precomputed table is saved and available via the #table method at any
  # time. The format of this table is described in the #table method's comments.
  #
  def calculate!
    @table = []
    calc   = self.calculator
    unders = {
      :active   => [],
      :inactive => []
    }
    CompanyUnderwriter.all(:conditions => { :CompanyID => self.company.id }).each do |cu|
      next unless cu.underwriter and cu.underwriter.IsActive?
      if cu.IsActive?
        unders[:active] << cu.underwriter
      else
        unders[:inactive] << cu.underwriter
      end
    end
    (unders[:active].sort_by(&:Underwriter) + unders[:inactive].sort_by(&:Underwriter)).each do |u|
      entry = {}
      entry[:underwriter_id]   = u.id
      entry[:underwriter_name] = u.Underwriter
      entry[:manual]           = u.manual(self.version_id)
      entry[:enabled]          = u.enabled?(self.company_id)
      entry[:selected]         = u.id == self.underwriter_id

      # Calculate amounts
      tmp_1, tmp_2, tmp_3 = nil, {}, {}
      if entry[:enabled]
        if self.policy_1_amount and self.policy_1_type
          tmp_1 = calc.calculate_rate(
            u, 1,
            self.policy_1_amount,
            self.policy_1_type,
            self.policy_1_is_developer?,
            false,
            self.policy_1_prior_amount,
            self.policy_1_prior_date,
            self.policy_2_amount,
            self.policy_2_type
          )
        end
        if self.policy_2_amount and self.policy_2_type
          tmp_2 = calc.calculate_rate(
            u, 2,
            self.policy_2_amount,
            self.policy_2_type,
            self.policy_2_is_developer?,
            self.policy_2_is_refinance?,
            self.policy_2_prior_amount,
            self.policy_2_prior_date,
            self.policy_1_amount,
            self.policy_1_type
          )
        end
        if self.policy_3_amount and self.policy_3_type
          tmp_3 = calc.calculate_rate(
            u, 3,
            self.policy_3_amount,
            self.policy_3_type,
            self.policy_3_is_developer?,
            false,
            self.policy_3_prior_amount,
            self.policy_3_prior_date,
            self.policy_1_amount,
            self.policy_1_type
          )
        end
      end

      # Save off amounts and add entry to @table
      entry[:amount_1]          = tmp_1
      entry[:amount_2]          = tmp_2[:rate] rescue nil
      entry[:amount_3]          = tmp_3[:rate] rescue nil
      entry[:no_split_amount_1] = nil
      entry[:no_split_amount_2] = tmp_2[:no_split] rescue nil
      entry[:no_split_amount_3] = tmp_3[:no_split] rescue nil
      entry[:display_1]         = entry[:amount_1] ? entry[:amount_1].to_currency : "N/A"
      entry[:display_2]         = entry[:amount_2] ? entry[:amount_2].to_currency + (entry[:no_split_amount_2] ? " &mdash; No Split: #{entry[:no_split_amount_2].to_currency}".html_safe : "") : "N/A"
      entry[:display_3]         = entry[:amount_3] ? entry[:amount_3].to_currency + (entry[:no_split_amount_3] ? " &mdash; No Split: #{entry[:no_split_amount_3].to_currency}".html_safe : "") : "N/A"
      @table << entry
    end
    @table
  end
end
