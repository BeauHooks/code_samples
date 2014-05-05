class EmployeePosition < ActiveRecord::Base
  self.table_name  = "tblEmployeePositions"
  self.primary_key = "ID"

  has_many :employees, foreign_key: "Position", primary_key: "ID", order: "ID"

end
