class Adjustment < DisburseBase
  self.table_name 	= "tblAdjustment"
  self.primary_key 	= "docnumber"

  belongs_to :company,   foreign_key: "CompanyID",  primary_key: "CompanyID"
  belongs_to :employee,  foreign_key: "EmployeeID", primary_key: "ID"
  belongs_to :file_info, foreign_key: "fileid",     primary_key: "FileID"

end
