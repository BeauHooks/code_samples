class FileEmail < ActiveRecord::Base
  self.table_name  = "tblFileEmails"
  self.primary_key = "id"

  belongs_to :index,   foreign_key: "FileID",  primary_key: "FileID"
  has_one    :message, foreign_key: "id",      primary_key: "message_id"

end
