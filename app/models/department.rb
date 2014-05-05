class Department < ActiveRecord::Base
  self.table_name  = "tblDepartments"
  self.primary_key = "ID"

  has_many :employees, foreign_key: "Department", primary_key: "ID", order: "ID"

end
