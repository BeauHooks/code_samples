class Alth < ActiveRecord::Base
	self.table_name  = "tblALTH"
  self.primary_key = "ALTHID"

  default_scope { order("Shortcut ASC") }

end
