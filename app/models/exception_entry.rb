class ExceptionEntry < ActiveRecord::Base
  self.table_name  = "tblExceptionEntries"
  self.primary_key = "EntryID"

  default_scope{ where("FileDate IS NOT NULL").order("FileDate DESC") }

  belongs_to :import_schedule_b,   foreign_key: :ExceptionID,       primary_key: :ID
  belongs_to :file_exception,      foreign_key: :ExceptionID,       primary_key: :ID
  has_many :schedule_b_exceptions, foreign_key: :ExceptionUniqueID, primary_key: :ExceptionID, order: "ModifiedDT, DESC"

  def content
  	return self.import_schedule_b.ExceptionText if self.IsImport?
		return self.file_exception.ExceptionText if self.IsFileExc?
		return self.schedule_b_exceptions.first.ExceptionText if self.IsNewExc?
		return "{{ExceptionText}}"
  end

  def source
    return "import" if self.IsImport?
    return "file" if self.IsFileExc?
    return "new"
  end
end