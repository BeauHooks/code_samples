class Taxroll3  < NewStatsBase
  self.table_name 	= "taxroll3"

  belongs_to :property, class_name: 'Taxroll2', foreign_key: 'accountnum', primary_key: 'accountnum'
  belongs_to :subdivision,                      foreign_key: 'ID',         primary_key: 'SubdivisionID'
  belongs_to :taxroll1,                         foreign_key: "accountnum", primary_key: "accountnum"

  def taxroll1
    Taxroll1.where("accountnum = #{self.accountnum} AND CountyID = #{self.CountyID}").first
  end
end
