class Subdivision < NewStatsBase
  self.table_name = 'tblSubdivision'
  self.primary_key = 'ID'

  belongs_to :area,   foreign_key: 'AreaCode', primary_key: 'Area'
  belongs_to :county, foreign_key: 'CountyID', primary_key: 'County'

end
