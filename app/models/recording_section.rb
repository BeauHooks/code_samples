class RecordingSection < NewStatsBase
  self.table_name   = "tblUTSect"
  self.primary_key  = "ID"

  belongs_to :county,          foreign_key: 'CountyID',    primary_key: 'CountyID'
  belongs_to :recording_entry, foreign_key: 'entrynumber', primary_key: 'EntryNum'

end
