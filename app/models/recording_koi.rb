class RecordingKoi < NewStatsBase
  self.table_name   = "tblKOI"
  self.primary_key  = "ID"
  #quick fix since this table uses the column name 'type', which is AR reserved.
  self.inheritance_column = "type_id"

  belongs_to :county,            foreign_key: 'CountyID', primary_key: 'CountyID'
  has_many   :recording_entries, foreign_key: 'koi',      primary_key: 'koi'

end
