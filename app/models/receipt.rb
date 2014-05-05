class Receipt < DisburseBase
  self.table_name  = "tblReceipts"
  self.primary_key = "ReceiptID"

  belongs_to :company,                         foreign_key: "CompanyID",   primary_key: "CompanyID"
  belongs_to :employee,                        foreign_key: "EmployeeID",  primary_key: "Initials"
  belongs_to :office,                          foreign_key: "OfficeID",    primary_key: "ID"
  belongs_to :file_info,                       foreign_key: "FileID",      primary_key: "FileID"
  has_one    :type,                            foreign_key: "TypeID",      primary_key: "PaymentMethod"
  has_one    :wire_in, class_name: "WiresIn",  foreign_key: "ID",          primary_key: "WireInID"

  def payment_type
  	self.type.nil? ? "" : self.type.Receipted_Type
  end

  def office_name
  	self.office.nil? ? "" : self.office.OfficeName
  end

  def depositor
    self.employee.nil? ? "" : self.employee.FullName
  end
end
