class FileUserType < ActiveRecord::Base
  self.table_name  = "tblFileUserTypes"
  self.primary_key = "ID"

  has_many :file_entities, foreign_key: "Position", primary_key: "ID", order: "FileID"

end
