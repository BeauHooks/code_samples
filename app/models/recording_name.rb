class RecordingName < NewStatsBase
  self.table_name   = "tblUTNames"
  self.primary_key  = "ID"

  belongs_to :county,                                         foreign_key: 'CountyID',     primary_key: 'CountyID'
  belongs_to :recording_entry,                                foreign_key: 'entrynumber',  primary_key: 'EntryNum'
  has_one    :recording_entry,                                foreign_key: 'entrynumber',  primary_key: 'EntryNum'
  belongs_to :recording_from,  class_name: 'RecordingEntry',  foreign_key: 'entrynumber',  primary_key: 'EntryNum'
  belongs_to :recording_to,    class_name: 'RecordingEntry',  foreign_key: 'entrynumber',  primary_key: 'EntryNum'

end
