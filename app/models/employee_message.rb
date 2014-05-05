class EmployeeMessage < ActiveRecord::Base
  self.table_name  = "tblEmployeeMessages"
  self.primary_key = "EMessageID"

  belongs_to :employee,                          foreign_key: "SentTo", primary_key: "ID"
  belongs_to :recipient, class_name: "Employee", foreign_key: "SentTo", primary_key: "ID"
  belongs_to :sender,    class_name: "Employee", foreign_key: "SentBy", primary_key: "ID"
  belongs_to :completer, class_name: "Employee", foreign_key: "DoneBy", primary_key: "ID"

end
