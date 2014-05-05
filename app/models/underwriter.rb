class Underwriter < ActiveRecord::Base
  self.table_name  = "tblUnderwriter"
  self.primary_key = "ID"

  has_many :company_underwriters,                             foreign_key: "UnderwriterID",      primary_key: "ID", order: "CompanyID"
  has_many :companies_im_default_for, class_name: "Company",  foreign_key: "DefaultUnderwriter", primary_key: "ID", order: "CompanyID"
  has_many :endorsements,                                     foreign_key: "Underwriter",        primary_key: "ID", order: "Endorsement"
  has_many :policy_types,                                     foreign_key: "UnderWriterID",      primary_key: "ID", order: "BasedOn, PolicyType, PolicyDescription, PolicyRate, ID"
  has_many :quotes,                                                                                                 order: :created_at
  has_many :rate_templates,                                   foreign_key: "Underwriter",        primary_key: "ID", order: "RateNum, TemplateID"
  has_many :files_as_primary,         class_name: "FileInfo", foreign_key: "Underwriter",        primary_key: "ID", order: "CompanyID, FileID"
  has_many :files_as_secondary,       class_name: "FileInfo", foreign_key: "SecondUnderwriter",  primary_key: "ID", order: "CompanyID, FileID"
  has_many :rate_calculations,                                                                   primary_key: "ID", order: "company_id, file_info_id, employee_id, created_at"
  has_many :web_communications,                               foreign_key: "UnderwriterID",      primary_key: "ID", order: "FileID, DummyTime"
  has_many :rate_calculators,                                 foreign_key: "Underwriter",        primary_key: "ID", order: "RateID"
  has_many :companies, through: :company_underwriters, uniq: true
  has_many :fp_standard_requirements

  # Retrieve the specified version of the underwriter's rate manual
  def manual(version)
    calc = rate_calculators.versioned(version).all
    return nil unless calc.length == 1
    return nil     if calc.first.rate_manual.blank?
    calc.first.rate_manual
  end

  # Determine if this underwriter is enabled for the specified company (id or object)
  def enabled?(company)
    company = company.id if company.is_a?(Company)
    assoc   = company_underwriters.find_by_CompanyID(company)
    assoc and assoc.IsActive? and assoc.underwriter and assoc.underwriter.IsActive?
  end

  def disabled?(company)
    !self.enabled?(company)
  end
end
