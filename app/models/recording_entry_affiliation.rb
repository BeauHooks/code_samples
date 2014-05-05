class RecordingEntryAffiliation < NewStatsBase
  self.table_name   = "tblUTEntryAffiliations"
  self.primary_key  = "AffiliationID"

  belongs_to :county,                                        foreign_key: 'CountyID',    primary_key: 'CountyID'
  belongs_to :first_entries,   class_name: 'RecordingEntry', foreign_key: 'entrynumber', primary_key: 'FirstNum'
  belongs_to :second_entries,  class_name: 'RecordingEntry', foreign_key: 'entrynumber', primary_key: 'SecondNum'
  has_one    :second_entry,    class_name: 'RecordingEntry', foreign_key: 'entrynumber', primary_key: 'SecondNum'
  has_one    :first_entry,     class_name: 'RecordingEntry', foreign_key: 'entrynumber', primary_key: 'FirstNum'

end
