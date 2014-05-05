class Index < ActiveRecord::Base
  require 'date'
  include ActionView::Helpers::NumberHelper
  self.table_name = "tblFileInfo"
  self.primary_key = "ID"

  SELECT_OPTIONS = [
                    ["File Number", "file_number"],
                    ["Buyer(s)", "buyers"],
                    ["Seller(s)", "sellers"],
                    ["Lender(s)", "lenders"],
                    ["Tax ID(s)", "tax_id"],
                    ["Realtor(s)", "realtors"],
                    ["Address", "address"],
                    ["Legal Desc", "legal_desc"],
                    ["Opened Date", "opened_date"],
                    ["Searched Date", "searched_date"],
                    ["PR Out Date", "pr_out_date"],
                    ["Bombed Date", "bombed_date"],
                    ["Recorded Date", "recorded_date"],
                    ["Policy Out Date", "policy_out_date"],
                    ["Employee", "employee"],
                    ["All Names", "all_names"],
                    ["Searcher", "searcher"],
                    ["Reservations", "reservations"],
                    ["SUTC ID", "sutc_id"],
                    ["COE Date", "coe_date"],
                    ["Policy Number", "policy_number"],
                    ["Loan Number", "loan_number"],
                    ["Loan Number 2", "loan_number_2"],
                    ["Claim Status", "claim_status"],
                    ["Referred By", "referred_by"],
                    ["Smart Search", "smart_search"]
                  ]

  SEARCH_DISPLAY = [
                    { label: 'File #',  attribute: 'FileID',                  style: 'w80',  format: 'to_s', limit: 0,  to_link: true,  link_type: 'file' },
                    { label: 'Buyer',   attribute: 'Buyer1',                  style: 'w130', format: 'to_s', limit: 18, to_link: true,  link_type: 'buyer',  association: "buyer_1"  },
                    { label: 'Seller',  attribute: 'Seller1',                 style: 'w130', format: 'to_s', limit: 18, to_link: true,  link_type: 'seller', association: "seller_1" },
                    { label: 'Lender',  attribute: 'Lender1',                 style: 'w130', format: 'to_s', limit: 18, to_link: true,  link_type: 'lender', association: "lender"   },
                    { label: 'Closer',  attribute: 'CloserName',              style: 'w130', format: 'to_s', limit: 18, to_link: false, link_type: '' },
                    { label: 'Type',    attribute: 'TransactionDescription1', style: 'w130', format: 'to_s', limit: 0,  to_link: false, link_type: '' },
                    { label: 'Address', attribute: 'Address1',                style: 'w130', format: 'to_s', limit: 18, to_link: false, link_type: '' },
                    { label: 'Stage',   attribute: 'stage',                   style: 'w130', format: 'to_s', limit: 0,  to_link: false, link_type: '' },
                    { label: 'Tax Id',  attribute: 'TaxID1',                  style: 'w125', format: 'to_s', limit: 18, to_link: false, link_type: '' },
                  ]

  before_save :update_convienence_fields
  after_save :update_related

  default_scope group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC")

  scope :tax_id, ->(query, search_value, options={}) { where("#{query} tblFileProperties.TaxID LIKE '#{search_value}%%'").joins(:file_properties).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :sutc_id, ->(query, search_value, options={}) { where("#{query} tblFileProperties.SUTCID LIKE '#{search_value}%%'").joins(:file_properties).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :legal_desc, ->(query, search_value, options={}) { where("#{query} tblFileProperties.LegalDescription LIKE '#{search_value}%%'").joins(:file_properties).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :all_names, ->(query, search_value, options={}) { where("#{query} tblEntities.FullName LIKE '#{search_value}%%'").joins(:entities).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :employee, ->(query, search_value, options={}) { where("#{query} (tblEmployees.FullName LIKE '#{search_value}%%' OR tblEmployees.FullName LIKE '#{search_value.gsub(',', '').split(' ').reverse.join(' ')}%%')").joins(:employees).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :searcher, ->(query, search_value, options={}) { where("#{query} (tblEmployees.FullName LIKE '#{search_value}%%' OR tblEmployees.FullName LIKE '#{search_value.gsub(',', '').split(' ').reverse.join(' ')}%%') AND tblFileEmployees.Position = 'Searcher'").joins(:employees).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :buyers, ->(query, search_value, options={}) { where("#{query} tblEntities.FullName LIKE '#{search_value}%%' AND tblFileEntities.Position = 1").joins(:entities).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :sellers, ->(query, search_value, options={}) { where("#{query} tblEntities.FullName LIKE '#{search_value}%%' AND tblFileEntities.Position = 2").joins(:entities).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :lenders, ->(query, search_value, options={}) { where("#{query} tblEntities.FullName LIKE '#{search_value}%%' AND tblFileEntities.Position = 3").joins(:entities).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :realtors, ->(query, search_value, options={}) { where("#{query} tblEntities.FullName LIKE '#{search_value}%%' AND tblFileEntities.Position IN (4, 5, 6)").joins(:entities).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :referred_by, ->(query, search_value, options={}) { where("#{query} tblEntities.FullName LIKE '#{search_value}%%' AND tblFileEntities.Position = 15").joins(:entities).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :address, ->(query, search_value, options={}) { where("#{query} tblFileProperties.PropertyAddress LIKE '#{search_value}%%'").joins(:file_properties).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :reservations, ->(query, search_value, options={}) { where("#{query} tblFileInfo.TransactionDescription1 = '#{search_value}'").order("CAST(DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :policy_out_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.PolicyOut >= '#{Index.datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.PolicyOut <= '#{Index.datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :opened_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.Opened >= '#{datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.Opened <= '#{datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :searched_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.SearchedDate >= '#{datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.SearchedDate <= '#{datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :pr_out_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.PROutDate >= '#{datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.PROutDate <= '#{datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :bombed_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.Bombed >= '#{datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.Bombed <= '#{datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :recorded_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.RecordedDate >= '#{datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.RecordedDate <= '#{datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :coe_date, ->(query, search_value, options={}) do
    query += "tblFileInfo.COEDate >= '#{datetime_parse(options[:from])}'" if options[:from]
    query += " AND " if options[:to] && options[:from]
    query += "tblFileInfo.COEDate <= '#{datetime_parse(options[:to])}'" if options[:to]
    where(query).limit(100)
  end
  scope :policy_number, ->(query, search_value, options={}) { where("#{query} tblFileInfo.PolicyNum LIKE '#{search_value}%%'").limit(100) }
  scope :loan_number, ->(query, search_value, options={}) { where("#{query} tblFileInfo.LoanNum LIKE '#{search_value}%%'").group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :loan_number_2, ->(query, search_value, options={}) { where("#{query} tblFileInfo.LoanNum2 LIKE '#{search_value}%%'").group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :claim_status, ->(query, search_value, options={}) { where("#{query} tblFileInfo.ClaimStatus LIKE '#{search_value}%%'").group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100) }
  scope :query, ->(query) { where(query).limit(100) }

  has_many   :file_employees,                                                                                     primary_key: "ID", order: "DummyTime ASC", conditions: "is_active = -1", dependent: :delete_all
  has_many   :old_file_employees,           class_name: "FileEmployee",    foreign_key: "FileID",                 primary_key: "FileID", order: "DummyTime ASC", conditions: "is_active = -1"
  has_many   :file_properties,                                                                                    primary_key: "ID", order: "ParcelNum", conditions: "Inactive = 0", dependent: :delete_all
  has_many   :old_file_properties,          class_name: "FileProperty",    foreign_key: "FileID",                 primary_key: "FileID", order: "ParcelNum", conditions: "Inactive = 0"
  has_many   :file_entities,                                                                                      primary_key: "ID", order: "tblFileEntities.Position, tblFileEntities.DummyTime DESC", dependent: :delete_all
  has_many   :old_file_entities,            class_name: "FileEntity",      foreign_key: "FileID",                 primary_key: "FileID", order: "tblFileEntities.Position, tblFileEntities.DummyTime DESC"
  has_many   :file_notes,                                                                                         primary_key: "ID", order: "NoteID", dependent: :delete_all
  has_many   :old_file_notes,               class_name: "FileNote",        foreign_key: "FileID",                 primary_key: "FileID", order: "NoteID"
  has_many   :lenders,                      class_name: 'FileEntity',      foreign_key: "FileID",                 primary_key: "FileID", :conditions => "Position = 3"
  has_many   :borrowers,                    class_name: 'FileEntity',      foreign_key: "FileID",                 primary_key: "FileID", :conditions => "Position = 1 || Position = 7"
  has_many   :entities,                     through: :file_entities
  has_many   :employees,                    through: :file_employees
  has_many   :closing_protection_letters,                                  foreign_key: 'index_id',               primary_key: "ID"
  has_many   :file_assignments,                                            foreign_key: "file_id",                primary_key: "FileID", order: "created_at"
  has_many   :filing1099s,                                                 foreign_key: "FileID",                 primary_key: "FileID"
  has_many   :huds, through: :docs, conditions: "docs.is_active != 0"
  has_many   :invoices,                                                    foreign_key: "Fileid",                 primary_key: "FileID"
  has_many   :check_workings,                                              foreign_key: "file_id",                primary_key: "FileID"
  has_many   :hud_line_payments,                                           foreign_key: "destination_file_id",    primary_key: "FileID"
  has_many   :file_doc_entities,                                           foreign_key: "file_id",                primary_key: "FileID"
  has_many   :file_doc_fields,                                             foreign_key: "file_id",                primary_key: "FileID"
  has_many   :file_doc_entities,                                           foreign_key: "file_id",                primary_key: "FileID", order: "sort_order"
  has_many   :docs,                                                        foreign_key: "file_id",                primary_key: "FileID"
  has_many   :active_docs, class_name: "Doc",                                                        foreign_key: "file_id",                primary_key: "FileID", conditions: "docs.is_active != 0"
  has_many   :adjustments,                                                 foreign_key: "fileid",                 primary_key: "FileID", order: "AdjustType, EmployeeID, adjdate"
  has_many   :checks,                                                      foreign_key: "FileID",                 primary_key: "FileID", order: "FundsType, ID"
  has_many   :deliveries,                                                  foreign_key: "FileID",                 primary_key: "FileID", order: "EnteredDT"
  has_many   :files_im_prior_for,           class_name: "FileInfo",        foreign_key: "PriorFileNum",           primary_key: "FileID", order: "PriorEffectiveDate"
  has_many   :file_emails,                                                 foreign_key: "FileID",                 primary_key: "FileID", order: "id"
  has_many   :file_endorsements,                                           foreign_key: "FileID",                 primary_key: "FileID", order: "ID"
  has_many   :file_images,                                                 foreign_key: "FileID",                 primary_key: "FileID"
  has_many   :file_products,                                               foreign_key: "file_id",                primary_key: "FileID", conditions: "is_active != 0"
  has_many   :file_product_olds,                                           foreign_key: "FileID",                 primary_key: "FileID", conditions: "IsActive != 0"
  has_many   :file_properties_im_prior_for, class_name: "FileProperty",    foreign_key: "PriorFile",              primary_key: "FileID", order: "ID"
  has_many   :file_rules,                   class_name: "FileRules",       foreign_key: "FileID",                 primary_key: "FileID", order: "RuleID"
  has_many   :vendor_trak_file_borrowers,                                  foreign_key: "FileID",                 primary_key: "FileID", order: "id"
  has_one    :vendor_trak_file_info,                                       foreign_key: "FileID",                 primary_key: "FileID"
  has_many   :schedule_a_old_histories,                                    foreign_key: "FileID",                 primary_key: "FileID", order: "Product, FieldName, ID DESC"
  has_many   :schedule_a_olds,                                             foreign_key: "FileID",                 primary_key: "FileID"
  has_many   :property_reports,             class_name: "ScheduleAOld",    foreign_key: "FileID",                 primary_key: "FileID", conditions: "Product = 'PR' OR Product LIKE 'PR~%'"
  has_many   :rate_calculations,                                           foreign_key: "file_info_id",           primary_key: "FileID", order: "employee_id, created_at"
  has_many   :receipts,                                                    foreign_key: "FileID",                 primary_key: "FileID", order: "PaymentType, EmployeeID, DateReceived"
  has_many   :web_communications,                                          foreign_key: "FileID",                 primary_key: "FileID", order: "DummyTime"
  has_many   :recon_trackings,              class_name: "ReconTracking",   foreign_key: "FileID",                 primary_key: "FileID", conditions: "InActive = 0"
  belongs_to :reviewed_by,                  class_name: "Employee",        foreign_key: "FileReviewedBy",         primary_key: "ID"
  belongs_to :county,                                                      foreign_key: "CountyID",               primary_key: "CountyID"
  belongs_to :company,                                                     foreign_key: "Company",                primary_key: "CompanyID"
  belongs_to :transaction_type,                                            foreign_key: "TransactionType",        primary_key: "ID"
  belongs_to :closing_office,               class_name: "Office",          foreign_key: "RequestedClosingOffice", primary_key: "ID"
  belongs_to :check_printing_office,        class_name: "Office",          foreign_key: "PrintCheckOffice",       primary_key: "ID"
  belongs_to :prior_file,                   class_name: "FileInfo",        foreign_key: "PriorFileNum",           primary_key: "FileID"
  belongs_to :underwriter,                                                 foreign_key: "Underwriter",            primary_key: "ID"
  belongs_to :second_underwriter,           class_name: "Underwriter",     foreign_key: "SecondUnderwriter",      primary_key: "ID"
  belongs_to :closer,                       class_name: "Employee",        foreign_key: "CloserAssigned",         primary_key: "ID"
  belongs_to :searcher,                     class_name: "Employee",        foreign_key: "SearcherAssigned",       primary_key: "ID"
  belongs_to :assistant,                    class_name: "Employee",        foreign_key: "AssistantAssigned",      primary_key: "ID"
  belongs_to :buyer_1,                      class_name: "Entity",          foreign_key: "Buyer1",                 primary_key: "EntityID"
  belongs_to :buyer_2,                      class_name: "Entity",          foreign_key: "Buyer2",                 primary_key: "EntityID"
  belongs_to :seller_1,                     class_name: "Entity",          foreign_key: "Seller1",                primary_key: "EntityID"
  belongs_to :seller_2,                     class_name: "Entity",          foreign_key: "Seller2",                primary_key: "EntityID"
  belongs_to :lender,                       class_name: "Entity",          foreign_key: "Lender1",                primary_key: "EntityID"
  belongs_to :owner_type,                   class_name: "PolicyType",      foreign_key: "OwnerType",              primary_key: "ID"
  belongs_to :alta_type,                    class_name: "PolicyType",      foreign_key: "ALTAType",               primary_key: "ID"
  belongs_to :second_type,                  class_name: "PolicyType",      foreign_key: "SecondType",             primary_key: "ID"
  has_many   :schedule_as,                  through: :file_products

  # Employee Action-Tracking Relationships
  belongs_to :order_taken_by,               class_name: "Employee",        foreign_key: "OrderTakenBy",           primary_key: "ID"
  belongs_to :date_down_entered_by,         class_name: "Employee",        foreign_key: "DateDownEnteredBy",      primary_key: "ID"
  belongs_to :dated_down_by,                class_name: "Employee",        foreign_key: "DatedDownBy",            primary_key: "ID"
  belongs_to :pr_reviewd_by,                class_name: "Employee",        foreign_key: "PRReviewedBy",           primary_key: "ID"
  belongs_to :pr_proof_by,                  class_name: "Employee",        foreign_key: "PRProofBy",              primary_key: "ID"
  belongs_to :pr_approved_by,               class_name: "Employee",        foreign_key: "PRApprovedBy",           primary_key: "ID"
  belongs_to :pr_out_by,                    class_name: "Employee",        foreign_key: "PROutBY",                primary_key: "ID"
  belongs_to :file_reviewed_by,             class_name: "Employee",        foreign_key: "FileReviewedBy",         primary_key: "ID"
  belongs_to :policy_approved_by,           class_name: "Employee",        foreign_key: "PolApprovedBy",          primary_key: "ID"
  belongs_to :funded_by,                    class_name: "Employee",        foreign_key: "FundedBy",               primary_key: "ID"
  belongs_to :recorded_by,                  class_name: "Employee",        foreign_key: "RecordedBy",             primary_key: "ID"
  belongs_to :ok_to_disburse_approved_by,   class_name: "Employee",        foreign_key: "DisbOKToApproveBy",      primary_key: "ID"
  belongs_to :disbursed_by,                 class_name: "Employee",        foreign_key: "DisbursedBy",            primary_key: "ID"
  belongs_to :balanced_by,                  class_name: "Employee",        foreign_key: "BalancedBy",             primary_key: "ID"
  belongs_to :locked_by,                    class_name: "Employee",        foreign_key: "LockedBy",               primary_key: "ID"
  belongs_to :rpt_closed_by,                class_name: "Employee",        foreign_key: "RptClosedBy",            primary_key: "ID"

  has_many :settlement_statements, through: :active_docs
  has_many :ss_lines, through: :settlement_statements, conditions: "ss_lines.is_active != 0"
  has_many :hud_lines, through: :huds
  has_many :ss_poc_payments, through: :ss_lines
  has_many :hud_poc_payments, through: :hud_lines

  accepts_nested_attributes_for :file_employees, :file_entities, :file_properties, :file_notes

  def self.split_companies
    [
      ["American Secure", "American Secure"],
      ["Atlas", "Atlas"],
      ["Backman", "Backman"],
      ["Cedar Land", "Cedar Land"],
      ["Dixie", "Dixie"],
      ["Equity", "Equity"],
      ["Executive", "Executive"],
      ["FATCO", "FATCO"],
      ["First Title", "First Title"],
      ["Inwest", "Inwest"],
      ["Meridian", "Meridian"],
      ["Mountain View", "Mountain View"],
      ["Prestige", "Prestige"],
      ["Provo Land", "Provo Land"],
      ["Security", "Security"],
      ["Skyview", "Skyview"],
      ["SUTICO", "SUTICO"],
      ["Sun West", "Sun West"],
      ["TERRA", "TERRA"],
      ["Title Guarantee", "Title Guarantee"],
      ["United Title", "United Title"]
    ]
  end

  def self.search_types
    [
      ["File Number", "file_number"],
      ["Buyer(s)", "buyers"],
      ["Seller(s)", "sellers"],
      ["Lender(s)", "lenders"],
      ["Tax ID(s)", "tax_id"],
      ["Realtor(s)", "realtors"],
      ["Address", "address"],
      ["Legal Desc", "legal_desc"],
      ["Opened Date", "opened_date"],
      ["Searched Date", "searched_date"],
      ["PR Out Date", "pr_out_date"],
      ["Bombed Date", "bombed_date"],
      ["Recorded Date", "recorded_date"],
      ["Policy Out Date", "policy_out_date"],
      ["Employee", "employee"],
      ["All Names", "all_names"],
      ["Searcher", "searcher"],
      ["Reservations", "reservations"],
      ["SUTC ID", "sutc_id"],
      ["COE Date", "coe_date"],
      ["Policy Number", "policy_number"],
      ["Loan Number", "loan_number"],
      ["Loan Number 2", "loan_number_2"],
      ["Claim Status", "claim_status"],
      ["Referred By", "referred_by"],
      ["Smart Search", "smart_search"]
    ]
  end

  def existing_disbursement_options
    options = [["New", "new"]]
    self.check_workings.each do |disbursement|
      options << ["#{disbursement.funds_type.titleize} to #{disbursement.payee_1} - #{number_to_currency( disbursement.amount, unit: "$")}", "#{disbursement.id}"]
    end
    return options
  end

  def existing_disbursement_options_list
    options = []
    self.check_workings.each do |disbursement|
      options << disbursement.payee_1
    end
    return options
  end

  def poc_payments
    return self.ss_poc_payments + self.hud_poc_payments
  end

  def poc_payment_sum
    return self.ss_poc_payments.sum("amount") + self.hud_poc_payments.sum("amount")
  end

  def payment_lines
    # TODO - Figure out a faster way to only pull back the lines that require a payment.
    lines = []
    self.ss_lines.each do |line|
      lines << line unless line.get("payee_name").blank? || line.payment_amount == 0
    end

    self.hud_lines.each do |line|
      lines << line unless line.get("payee_name").blank? || line.payment_amount == 0
    end
    return lines
  end

  def is_destroyable?; self.FileID.nil?; end

  def self.in_progress(employee_id)
    find_by_FileID_and_OrderTakenBy(nil, employee_id)
  end

  def self.datetime_parse(datetime)
    # Format the date because rails and sql don't like americans
    split      = datetime.split(' ')
    split_date = split[0].split('/')
    month      = split_date[0]
    day        = split_date[1]
    year       = split_date[2]

    DateTime.parse("#{year}-#{month}-#{day} #{split[1]} #{split[2]}").strftime("%Y-%m-%d %H:%M:%S")
  end

  def search(search_by, search_value)
    where("? tblFileProperties.TaxID LIKE '?%'", search_by, search_value).joins(:file_properties).group("tblFileInfo.DisplayFileID").order("CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC").limit(100)
  end

  def agent_number
    CompanyUnderwriter.where(:CompanyID => self.company, :UnderwriterID => self.underwriter, :IsActive => -1).pluck(:AgentNumber).first
  end

  def authorization_code
    case self.underwriter.ID
    when 6
      "#{self.agent_number}ORNT"
    else
      "Underwriter not set up for Web CPL creation."
    end
  end

  def borrower_names
    names = ""
    self.borrowers.each_with_index do |borrower,index|
      names += " and " unless index == 0
      names += "#{borrower.entity.FirstName} #{borrower.entity.LastName}"
    end unless self.borrowers.empty?
    names
  end

  def buyer_names
    names = []
    self.entities.where("tblFileEntities.Position IN (1, 7)").each do |buyer|
      names << buyer.name
    end

    names.size > 2 ? names[0...-1].join(", ") + names[-1].join(", and ") : names.join(" and ")
  end

  def county_id
    return self.CountyID unless self.CountyID.blank?
    return self.file_properties.where("CountyID IS NOT NULL AND CountyID != ''").first.CountyID unless self.file_properties.where("CountyID IS NOT NULL AND CountyID != ''").first.nil?
    return self.company.DefaultCounty unless self.company.DefaultCounty.blank?
    return 4
  end

  def underwriter_name
    self.Underwriter.blank? ? "UNDERWRITER_NAME" : self.underwriter.Underwriter
  end

  def self.loan_transactions
    ["Refinance", "Construction Loan", "Long Term"]
  end

  def reviewer
    self.reviewed_by.blank? ? "" : self.reviewed_by.FullName
  end

  def self.can_view(user, company)
    return !user.has_permission?(:view_private_index, company: company) ? "  AND AdminViewPassword = '' AND (confidential = 0 OR (confidential != 0 AND tblFileEmployees.EmployeeID = #{user.employee_id} AND tblFileEmployees.is_active != 0)) " : "  AND AdminViewPassword = ''"
  end

  def update_related
    changed = self.changed
    if changed.include?("SalesPrice")
      hud = self.huds.first
      if hud != nil
        case hud.hud_type
        when "standard"
          line = hud.hud_lines.where("number = 101").first
          if line.borrower_amount.to_f != self.SalesPrice.to_f
            line.borrower_amount = self.SalesPrice.to_f
            line.save
          end
        when "in-house"
          line = hud.hud_lines.where("number = 3000").first
          if line.charges.to_f != self.SalesPrice.to_f
            line.charges = self.SalesPrice.to_f
            line.save
          end
        end
      end

      fields = self.file_doc_fields.where("tag LIKE '1099_GROSS_PROCEEDS_%' AND doc_id = 0 AND is_active != 0")
      fields.each do |field|
        amount = self.SalesPrice.to_i < self.SalesPrice.to_f ? self.SalesPrice.to_i + 1 : self.SalesPrice.to_i
        field.value = number_to_currency(amount, unit: "$", precision: 0)
        field.updated_at = Time.now.to_s(:db)
        # field.updated_by = current_user.employee_id
        field.save
      end
    end

    if changed.include?("LoanAmount")
      hud = self.huds.first
      if hud != nil
        case hud.hud_type
        when "standard"
          line = hud.hud_lines.where("number = 202").first
          if line.borrower_amount.to_f != self.LoanAmount.to_f
            line.borrower_amount = self.LoanAmount.to_f
            line.save
          end
        when "loan-in-house"
          line = hud.hud_lines.where("number = 5000").first
          if line.credits.to_f != self.LoanAmount.to_f
            line.credits = self.LoanAmount.to_f
            line.save
          end
        end

        hud.initial_loan_amount = self.LoanAmount.to_f
        hud.save
      end
    end

    if changed.include?("LoanNum")
      field = self.file_doc_fields.where("tag = 'LOAN_NUMBER' AND doc_id = 0 AND is_active != 0").first
      if field != nil
        field.value = self.LoanNum
        field.updated_at = Time.now.to_s(:db)
        # field.updated_by = current_user.employee_id
        field.save
      end
    end

    if changed.include?("COEDate")
      field = self.file_doc_fields.where("tag = 'CLOSING_DATE' AND doc_id = 0 AND is_active != 0").first
      if field != nil
        date = self.COEDate.to_s.split(" ")[0].split("-") rescue nil
        date = date != nil ? "#{date[1]}/#{date[2]}/#{date[0]}" : ""
        field.value = date
        field.updated_at = Time.now.to_s(:db)
        # field.updated_by = current_user.employee_id
        field.save
      end

      hud = self.huds.first
      if hud != nil && hud.tax_proration_date != self.COEDate
        hud.tax_proration_date = self.COEDate
        hud.save
      end
    end

    if changed.include?("Underwriter")
      self.schedule_as.each do |schedule_a|
        unless self.Underwriter == schedule_a.underwriter_id
          schedule_a.underwriter_id = self.Underwriter
          schedule_a.save
        end
      end
    end
  end

  def has_pr?
    return self.property_reports.last != nil
  end

  #
  # Check all the docs on a file to see if any have a template update
  #
  def has_doc_updates
    self.docs.where("is_active = -1").each do |doc|
     return true if doc.has_update?
    end
    return false
  end

  def docs_with_updates
    list = []

    self.docs.where("is_active = -1").each do |doc|
      if doc.has_update?
        list << doc.doc_template.short_name
      end
    end

    list.uniq!
    return list
  end

  def buyers_and_sellers
    return self.file_entities.where("Position IN (2, 1, 7)")
  end

  def closers
    return self.file_employees.where("Position LIKE 'Closer%%'")
  end

  def file_product_collection
    return self.file_products.collect{|p| [p.type, p.id]}
  end

  def old_file_product_collection
    return self.file_product_olds.collect{|p| [p.ProductName, p.ID]}
  end

  #
  # Check if file has any active doc entities
  #
  def has_active_entities?
    if self.file_doc_entities.where("is_active = 1").count > 0
      return true
    else
      return false
    end
  end

  def gather_file_entities
    hash = Hash.new
    choices = ""

    self.file_entities.each do |file_entity|
      if file_entity.entity != nil
        name = file_entity.entity.name.gsub(/'/, "\\\\\'").gsub('[', '').gsub(']', '').gsub('\n', '').gsub('\r', '')
        if choices == ""
          choices += "'#{name}'"
        else
          choices += ", '#{name}'"
        end
        hash[name] = file_entity.EntityID
      end
    end

    return hash, choices
  end

  # Totals all the "endorsement premiums" for all products of the specified
  # type attached to this file.
  #
  # NOTE: Replicates logic in RateCalculation.policy_endorsements_total
  # TODO: DRY this up: all business logic should be in one place ONLY!
  #
  def endorsement_premiums_total(product_type, amount = 0.0)
    result = 0.0
    endorsements = self.file_endorsements.find_all_by_Product(product_type)
    endorsements.reject { |e| e.endorsement.nil? }.each do |e|
      e_id, manual = e.id,             true
      e_id, manual = e.endorsement.id, false unless e.isManualRate?
      u_tmp        = e.endorsement.underwriter
      result      += RateLibrary.load(e.endorsement.calc_version).endorsement_premium(u_tmp, e_id, amount, manual)
    end
    result
  end

  #
  # Build a slash-seperated list, naming all the endorsements attached to this
  # file of the specified product type.
  #
  def endorsements_list(product_type)
    result = ""
    prefix = ""
    self.file_endorsements.find_all_by_Product(product_type).each do |e|
      if e.ShortName
        result << "#{prefix}#{e.ShortName}"
      else
        result << "#{prefix}#{e.EndorsementName}"
      end
      prefix = "/"
    end
    result
  end

  # The the value of a specific field for a specific product
  def schedule_a_old_value(product, field)
    ScheduleAHistory.value(self.FileID, product, field)
  end

  #
  # Add a new value for the specified field for the specified product
  #
  def add_schedule_a_old_value(product, field, value, timestamp = nil, employee_id = nil)
    timestamp   ||= DateTime.now
    employee_id ||= 0
    schedule_a_old_histories.create(
      :DisplayFileID => self.DisplayFileID,
      :Product       => product,
      :FieldName     => field,
      :FieldValue    => value || "", # for now represent all nils as empty string
      :ModifiedBy    => employee_id,
      :ModifiedDT    => timestamp
    )
  end

  # Kingston-Project Specific Query Field
  def kms?
    self.IsKMSFile?
  end

  # Quick Query: are both loan number fields defined?
  def loan_numbers_defined?
    !self.LoanNum.blank? and !self.LoanNum2.blank?
  end

  # Return the first 'Closer' employee record associated with this file
  def first_closer
    self.file_employees.closers.each do |c|
      next unless c.employee and c.employee.Active? and not c.employee.IsTitle?
      return c
    end
    nil
  end

  # Retrieve the file's balance (receipts - checks + adjustments)
  def balance(now = DateTime.now)
    result = BigDecimal.new('0')
    #
    # First add all our receipts to the total...
    #
    self.receipts.reject { |r| r.PaymentMethod == '1' or r.DateOfGoodFunds > now or r.void? }.each do |r|
      result += BigDecimal.new(r.ReceiptAmount.to_s) unless r.ReceiptAmount.nil?
    end
    #
    # Now, subtract checks from our total balance...
    #
    self.checks.each { |c| result -= BigDecimal.new(c.Amount.to_s) unless c.Void? or c.Amount.nil? }
    #
    # Now apply all adjustments...
    #
    self.adjustments.each { |a| result += BigDecimal.new(a.incrdeccash.to_s) unless a.incrdeccash.nil? }
    result
  end

  #
  # Quick method that will mark this file as disbursed. You may specify the
  # date/time of the 'Disbursed' field. The default will use the current time.
  # Saves the record and raises an exception on error.
  #
  # NOTE: does nothing if file isn't yet recorded or if it is already disbursed
  #
  def mark_disbursed!(at = nil)
    at ||= DateTime.now
    if self.Recorded and self.Disbursed.nil?
      self.Disbursed = at
      self.save!
    end
  end

  STAGES = ["Opened", "Searched",  "PROut", "DateDownEntered", "DatedDown", "FileReviewed", "SentForFunding", "Funded", "Recorded", "Disbursed", "PolicyOut", "Bombed"]

  # Get the current stage
  def stage
    STAGES.reverse_each do |i|
      if self.send("#{i}".to_sym) != nil
        case i
        when "Opened"
          return "Opened - #{self.Opened.to_formatted_s(:short_date)}"
        when "Searched"
          return "Searched - #{self.Searched.to_formatted_s(:short_date)}"
        when "PROut"
          return "PR Out - #{self.PROut.to_formatted_s(:short_date)}"
        when "DateDownEntered"
          return "Sent for Date Down - #{self.DateDownEntered.to_formatted_s(:short_date)}"
        when "DatedDown"
          return "Dated Down - #{self.DatedDown.to_formatted_s(:short_date)}"
        when "FileReviewed"
          return "File Reviewed - #{self.FileReviewed.to_formatted_s(:short_date)}"
        when "SentForFunding"
          return "Sent for Funding - #{self.SentForFunding.to_formatted_s(:short_date)}"
        when "Funded"
          return "Funded - #{self.Funded.to_formatted_s(:short_date)}"
        when "Recorded"
          return "Recorded - #{self.Recorded.to_formatted_s(:short_date)}"
        when "Disbursed"
          return "Disbursed - #{self.Disbursed.to_formatted_s(:short_date)}"
        when "PolicyOut"
          return "Policy Out - #{self.PolicyOut.to_formatted_s(:short_date)}"
        when "Bombed"
          return "Bombed - #{self.Bombed.to_formatted_s(:short_date)}"
        else
          return ""
        end
      end
    end
    return ""
  end

  def closing_date
    if self.COEDate != "" && self.COEDate != nil
      return self.COEDate.to_formatted_s(:standard)
    else
      return ""
    end
  end

  def has_rules?
    self.entities.each do |entity|
      return true if entity.entity_rules.size > 0
    end
    false
  end

  def has_employee?(employee)
    return self.file_employees.where("EmployeeID = #{employee}").first != nil
  end

  def initialize_notaries(doc_id = 0)
    sides = ['GRANTOR', 'GRANTEE']

    sides.each do |side|
      defaults = self.set_default_notary(side, doc_id)
      doc_entities = self.file_doc_entities.where("doc_id = #{doc_id} AND tag = '#{side}' AND is_active != 0") - defaults

      list = ["NOTARY_VESTING", "NOTARY_DATE","NOTARY_COUNTY","NOTARY_STATE"]

      doc_entities.each do |doc_entity|
        list.each do |list_tag|
          field = self.file_doc_fields.where("tag = '#{side}_#{list_tag}_#{doc_entity.id}' AND doc_id=#{doc_id} AND is_active = 1").first
          use_default = false
          save = false

          if field == nil
            field = self.create_file_doc_field("#{side}_#{list_tag}_#{doc_entity.id}", doc_id)
            use_default = true
            save = true
          end

          case list_tag
          when "NOTARY_VESTING"
            field.value = doc_entity.generate_notary_text
            save = true
          else
            if use_default
              default = self.file_doc_fields.where("tag = '#{side}_#{list_tag}' AND doc_id=0").first
              field.value = default.value
            end
          end

          if save
            field.updated_at = Time.now.to_s(:db)
            field.save
          end
        end
      end
    end
  end

  def set_default_notary(side, doc_id = 0)
    value = ""
    defaults = []

    doc_entities = self.file_doc_entities.find(:all, joins: [:entity], conditions: ["tblEntities.IndCorp = 'Individual' AND doc_id = #{doc_id} AND tag = '#{side}' AND (split = 0 OR split IS NULL) AND is_active != 0"])
    size = doc_entities.size

    if size > 0
      count = 0
      doc_entities.each do |doc_entity|
        defaults << doc_entity
        count += 1
        if value == ""
          value = doc_entity.name
        elsif count == size && size == 2
          value += " and #{doc_entity.name}"
        elsif count < size
          value += ", #{doc_entity.name}"
        else
          value += ", and #{doc_entity.name}"
        end
      end

      value += ", the signer(s) of the above agreement who duly acknowledge to me that they executed the same" if value != ""
    else
      doc_entity = self.file_doc_entities.find(:all, joins: [:entity], conditions: ["tblEntities.IndCorp != 'Individual' AND doc_id = #{doc_id} AND tag = '#{side}' AND (split = 0 OR split IS NULL) AND is_active != 0"]).first
      if doc_entity != nil
        defaults << doc_entity
        value = doc_entity.generate_notary_text
      end
    end

    field = self.file_doc_fields.where("tag = '#{side}_NOTARY_VESTING' AND doc_id=#{doc_id} AND is_active = 1").first
    field = self.create_file_doc_field("#{side}_NOTARY_VESTING", doc_id) if field == nil
    field.value = value
    field.updated_at = Time.now.to_s(:db)
    field.save

    defaults
  end

  def create_file_doc_field(tag, doc_id)
    field = FileDocField.new
    field.doc_id = doc_id
    field.file_id = self.FileID
    field.tag = tag
    field.is_active = 1
    field.created_at = Time.now.to_s(:db)
    field.value = ""
    field.save
    field
  end

  # NOTE: WARNING -- these helpers reference hard-coded IDs (in Company model)
  #
  # A lot of code paths regarding files are hard-coded for specific companies.
  # Using these makes the code which is hard-coded for specific companies easier
  # to read and centralizes the hard-coded IDs in the Company model.
  #
  def sutc?          ; self.company.sutc?          ; end # Southern Utah Title Company
  def terra?         ; self.company.terra?         ; end # Terra Title Company
  def cedar?         ; self.company.cedar?         ; end # Southern Utah Title Company of Cedar City
  def mesquite?      ; self.company.mesquite?      ; end # Mesquite Title Company
  def affiliated?    ; self.company.affiliated?    ; end # Affiliated Real Estate Solutions
  def kanab?         ; self.company.kanab?         ; end # Southern Utah Title (Kanab Office)
  def land_ex?       ; self.company.land_ex?       ; end # Land Exchange Corporation
  def equity_escrow? ; self.company.equity_escrow? ; end # Equity Escrow
  def const_draw?    ; self.company.const_draw?    ; end # Equity Escrow Construction Draw
  def defaults4u?    ; self.company.defaults4u?    ; end # Defaults4U.com
  def recons4u?      ; self.company.recons4u?      ; end # recons4u.com
  def tmi?           ; self.company.tmi?           ; end # Title Managers Inc
  def vendor_trak?   ; self.company.vendor_trak?   ; end # VendorTrak Title Company
  def vendor_agency? ; self.company.vendor_agency? ; end # VendorTrak Title Insurance Agency, LLC
  def arizona?       ; self.company.arizona?       ; end # Mesquite Title Agency of Arizona

  def assign_file_id
    self.FileID = 101999999999
    # last_file = Index.select("DisplayFileID").where("Company = #{company} AND Opened > CAST('#{Time.now - 7.days}' AS DATE) AND Opened < CAST('#{Time.now + 1.days}' AS DATE)").order("DisplayFileID DESC").limit(1).first
    # @file.FileID = "#{company}#{display_file_id}"
    # display_file_id = last_file.DisplayFileID.to_i + 1
    # @file.DisplayFileID = display_file_id.to_s
  end

  private

  def update_convienence_fields
    if self.TransactionType_changed?
      transaction_type = self.transaction_type
      self[:TransactionDescription1] = transaction_type.TransactionDescription
    end
  end
end
