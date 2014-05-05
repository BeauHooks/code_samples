class FileException < ActiveRecord::Base
  self.table_name  = "tblFileExceptions"
  self.primary_key = "ID"

  default_scope{where("Include != 0").order("RealNum, ModifiedDT")}

  belongs_to :file_base, foreign_key: "BaseID", primary_key: "BaseID"

end