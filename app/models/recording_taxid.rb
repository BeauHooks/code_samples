class RecordingTaxid < NewStatsBase
  self.table_name   = "tblUTTaxID"
  self.primary_key  = "ID"

  belongs_to :county,                                        foreign_key: 'CountyID',    primary_key: 'CountyID'
  belongs_to :recording_entry,                               foreign_key: 'entrynumber', primary_key: 'EntryNumber'
  has_one    :taxid_entry,     class_name: 'RecordingEntry', foreign_key: 'entrynumber', primary_key: 'EntryNumber'

end
