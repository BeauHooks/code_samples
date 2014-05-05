class FileEmployeeType < ActiveRecord::Base
  self.table_name  = "tblFileEmployeeTypes"
  self.primary_key = "ID"

  default_scope { order("TypeDescription ASC") }

end
