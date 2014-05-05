class TransactionType < ActiveRecord::Base
  self.table_name  = "tblTransactionType"
  self.primary_key = "ID"

  default_scope { order('TransactionDescription ASC') }

  has_many   :files, class_name: "Index", foreign_key: "TransactionType", primary_key: "ID", order: "CompanyID, FileID"

end
