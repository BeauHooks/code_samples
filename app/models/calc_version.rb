class CalcVersion < ActiveRecord::Base
  self.table_name = "versions"

  has_many   :regions,                            foreign_key: :version_id,  primary_key: :id
  belongs_to :versioned_set
  belongs_to :created_by, class_name: "Employee", foreign_key: "created_by", primary_key: "ID"
  belongs_to :updated_by, class_name: "Employee", foreign_key: "updated_by", primary_key: "ID"

end
