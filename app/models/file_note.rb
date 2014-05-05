class FileNote < ActiveRecord::Base
  self.table_name  = "tblFileNotes"
  self.primary_key = "NoteID"

  default_scope { where("IsHidden = 0") }

  belongs_to :index,                                   foreign_key: "FileID",           primary_key: "FileID"
  belongs_to :vendor_trak_file_info,                   foreign_key: "FileID",           primary_key: "FileID"

  # Employee Action-Tracking Relationships
  belongs_to :entered_by,      class_name: "Employee", foreign_key: "EnteredBy",        primary_key: "ID"
  belongs_to :tickled_by,      class_name: "Employee", foreign_key: "TickleEmployeeID", primary_key: "ID"
  belongs_to :completed_by,    class_name: "Employee", foreign_key: "CompletedBy",      primary_key: "ID"

  # TODO: (NoteType Field Values)
  NOTE_TYPES = { 1 => "TODO", 3 => "TODO", 4 => "TODO", 5 => "TODO" }

  def entered_by_name; self.entered_by.nil? ? "" : self.entered_by.FullName; end
  def tickled_by_name; self.tickled_by.nil? ? "" : self.tickled_by.FullName; end
end
