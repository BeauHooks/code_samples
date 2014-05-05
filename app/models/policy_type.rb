class PolicyType < ActiveRecord::Base
  self.table_name  = "tblPolicyTypes"
  self.primary_key = "ID"

  default_scope {order("PolicyType ASC")}
  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(CalcVersion) ? v.id : v) } } }

  has_many   :files_with_this_as_owner_type,  class_name: "FileInfo",         foreign_key: "OwnerType",         primary_key: "ID",  order: "CompanyID, FileID"
  has_many   :files_with_this_as_alta_type,   class_name: "FileInfo",         foreign_key: "ALTAType",          primary_key: "ID",  order: "CompanyID, FileID"
  has_many   :files_with_this_as_second_type, class_name: "FileInfo",         foreign_key: "SecondType",        primary_key: "ID",  order: "CompanyID, FileID"
  has_many   :type_1_rate_calcs,              class_name: "RateCalculation",  foreign_key: "policy_1_type_id",  primary_key: "ID",  order: "company_id, file_info_id, employee_id, created_at"
  has_many   :type_2_rate_calcs,              class_name: "RateCalculation",  foreign_key: "policy_2_type_id",  primary_key: "ID",  order: "company_id, file_info_id, employee_id, created_at"
  has_many   :type_3_rate_calcs,              class_name: "RateCalculation",  foreign_key: "policy_3_type_id",  primary_key: "ID",  order: "company_id, file_info_id, employee_id, created_at"
  has_many   :rate_1_affiliations,            class_name: "RateAffiliation",  foreign_key: "Policy1ID",         primary_key: "ID",  order: "Policy2ID" # These provide direct access to the RateAffiliation...
  has_many   :rate_2_affiliations,            class_name: "RateAffiliation",  foreign_key: "Policy2ID",         primary_key: "ID",  order: "Policy1ID" # ...HABTM join table where PolicyType HABTM PolicyTypes
  has_many   :rate_templates,                                                 foreign_key: "PolicyID",          primary_key: "ID",  order: "RateNum, TemplateID"
  belongs_to :underwriter,                                                    foreign_key: "UnderWriterID",     primary_key: "ID"
  belongs_to :policy_form,                                                    foreign_key: "DefaultForm",       primary_key: "FormID" # Reference to the default form
  belongs_to :calc_version

end
