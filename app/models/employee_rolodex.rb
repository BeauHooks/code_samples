class EmployeeRolodex < ActiveRecord::Base
  self.table_name  = "tblEmployeeRolodex"

  belongs_to :employee, primary_key: "ID",       foreign_key: "EmployeeID"
  belongs_to :entity,   primary_key: "EntityID", foreign_key: "EntityID"

end
