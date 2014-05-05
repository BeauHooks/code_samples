class Office < ActiveRecord::Base
  self.table_name  = "tblOffices"
  self.primary_key = "ID"

  has_many   :checks,                                         foreign_key: "PrintOffice",            primary_key: "ID",        order: "CompanyID, FileID, FundsType, ID"
  has_many   :employees,                                      foreign_key: "ReceiptOffice",          primary_key: "ID",        order: "ID"
  has_many   :files_closing_here,  class_name: "FileInfo",    foreign_key: "RequestedClosingOffice", primary_key:"ID",         order: "CompanyID, FileID"
  has_many   :files_printing_here, class_name: "FileInfo",    foreign_key: "PrintCheckOffice",       primary_key: "ID",        order: "CompanyID, FileID"
  has_many   :receipts,                                       foreign_key: "OfficeID",               primary_key: "ID",        order: "CompanyID, FileID, PaymentType, EmployeeID, DateReceived"
  belongs_to :company,                                        foreign_key: "CompanyID",              primary_key: "CompanyID"
  belongs_to :county,                                         foreign_key: "CountyID",               primary_key: "CountyID"

end
