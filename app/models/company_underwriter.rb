class CompanyUnderwriter < ActiveRecord::Base
  self.table_name  = "tblCompanyUnderwriters"
  self.primary_key = "ID"

  belongs_to :company,     foreign_key: "CompanyID",     primary_key: "CompanyID"
  belongs_to :underwriter, foreign_key: "UnderwriterID", primary_key: "ID"

end
