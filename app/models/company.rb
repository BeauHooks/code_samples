class Company < ActiveRecord::Base
  self.table_name  = "tblCompany"
  self.primary_key = "CompanyID"

  has_many   :hud_line_payments,                              foreign_key: "company_id",         primary_key: "CompanyID"
  has_many   :adjustments,                                    foreign_key: "CompanyID",          primary_key: "CompanyID", order: "fileid, AdjustType, EmployeeID, adjdate"
  has_many   :checks,                                         foreign_key: "CompanyID",          primary_key: "CompanyID", order: "FileID, FundsType, ID"
  has_many   :company_underwriters,                           foreign_key: "CompanyID",          primary_key: "CompanyID", order: "UnderwriterID"
  has_many   :files,               class_name: "FileInfo",    foreign_key: "Company",            primary_key: "CompanyID", order: "FileID"
  has_many   :employees,                                      foreign_key: "Company",            primary_key: "CompanyID", order: "ID"
  has_many   :entities,                                       foreign_key: "CompanyID",          primary_key: "CompanyID", order: "EntityID"
  has_many   :offices,                                        foreign_key: "CompanyID",          primary_key: "CompanyID", order: "ID"
  has_many   :quotes
  has_many   :rate_calculations,                                                                 primary_key: "CompanyID", order: "file_info_id, employee_id, created_at"
  has_many   :receipts,                                       foreign_key: "CompanyID",          primary_key: "CompanyID", order: "FileID, PaymentType, EmployeeID, DateReceived"
  belongs_to :entity,                                         foreign_key: "EntityID",           primary_key: "EntityID"
  belongs_to :default_underwriter, class_name: "Underwriter", foreign_key: "DefaultUnderwriter", primary_key: "ID"
  belongs_to :default_county,      class_name: "County",      foreign_key: "DefaultCounty",      primary_key: "CountyID"
  has_many   :fp_standard_requirements
  has_many   :cpls, class_name: "ClosingProtectionLetter",    foreign_key: 'company_id',         primary_key: 'CompanyID'
  has_many   :underwriters, through: :company_underwriters, uniq: true
  has_and_belongs_to_many :users

  # Specifically get a list of underwriters for this company that are enabled.
  # This will be a subset (not necessarily "proper") of the "underwriters"
  # relationship.
  #
  def enabled_underwriters
    self.underwriters.reject { |u| u.disabled?(self.id) }
  end

  # Shorthand for WFM2MSendWires (can this company use M2M system for wires?)
  def m2m?
    self.WFM2MSendWires
  end

  # NOTE: WARNING -- these helpers use hard-coded IDs
  #
  # A lot of code paths are hard-coded for specific companies. This simplifies
  # and aggregates all the hard-coding of company ID numbers here. This also
  # make the code which is hard-coded for specific companies easier to read
  # when they user these short-cut query methods...
  #
  def sutc?          ; self.CompanyID == 101 ; end # Southern Utah Title Company
  def terra?         ; self.CompanyID == 102 ; end # Terra Title Company
  def cedar?         ; self.CompanyID == 103 ; end # Southern Utah Title Company of Cedar City
  def mesquite?      ; self.CompanyID == 104 ; end # Mesquite Title Company
  def affiliated?    ; self.CompanyID == 105 ; end # Affiliated Real Estate Solutions
  def kanab?         ; self.CompanyID == 106 ; end # Southern Utah Title (Kanab Office)
  def land_ex?       ; self.CompanyID == 107 ; end # Land Exchange Corporation
  def equity_escrow? ; self.CompanyID == 108 ; end # Equity Escrow
  def const_draw?    ; self.CompanyID == 109 ; end # Equity Escrow Construction Draw
  def defaults4u?    ; self.CompanyID == 110 ; end # Defaults4U.com
  def recons4u?      ; self.CompanyID == 111 ; end # recons4u.com
  def tmi?           ; self.CompanyID == 112 ; end # Title Managers Inc
  def vendor_trak?   ; self.CompanyID == 113 ; end # VendorTrak Title Company
  def vendor_agency? ; self.CompanyID == 115 ; end # VendorTrak Title Insurance Agency, LLC
  def arizona?       ; self.CompanyID == 116 ; end # Mesquite Title Agency of Arizona

  def self.collection
    self.find(:all, conditions: ["CompanyID IN (101,103,102,104,106,117)"], order: "CompanyName ASC").collect{|c| [c.CompanyName, c.CompanyID]}
  end
end
