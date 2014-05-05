class PolicyForm < ActiveRecord::Base
  self.table_name  = "tblPolicyForms"
  self.primary_key = "FormID"

  has_many   :policy_types,                          foreign_key: "DefaultForm",  primary_key: "FormID",  order: "UnderWriterID, BasedOn, PolicyType, PolicyDescription, PolicyRate, ID"
  belongs_to :approved_by,  class_name: "Employee",  foreign_key: "ApprovedBy",   primary_key: "ID"
  belongs_to :edited_by,    class_name: "Employee",  foreign_key: "EditedBy",     primary_key: "ID"
  belongs_to :typed_by,     class_name: "Employee",  foreign_key: "TypedBy",      primary_key: "ID"

end
