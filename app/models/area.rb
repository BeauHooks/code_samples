class Area < NewStatsBase
  self.table_name  = 'tblArea'
  self.primary_key = 'ID'

  has_many   :subdivisions,                       foreign_key: 'Area',     primary_key: 'AreaCode'
  belongs_to :county,                             foreign_key: 'CountyID', primary_key: 'CountyID'
  has_many   :properties, class_name: 'Taxroll2', foreign_key: 'CountyID', primary_key: 'CountyID'

end
