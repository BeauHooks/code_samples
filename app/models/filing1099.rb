class Filing1099 < ActiveRecord::Base
  self.table_name  = "tbl1099Filing"
  self.primary_key = "ID"

  belongs_to :index, foreign_key: "FileID", primary_key: "FileID"

end
