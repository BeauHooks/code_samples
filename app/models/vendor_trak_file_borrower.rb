class VendorTrakFileBorrower < ActiveRecord::Base
  self.table_name  	= "tblVTFileBorrowers"
  self.primary_key 	= "id"

  belongs_to :file_info,             foreign_key: "FileID", primary_key: "FileID"
  belongs_to :vendor_trak_file_info, foreign_key: "FileID", primary_key: "FileID"

end
