class Taxroll1 < NewStatsBase
  self.table_name   = "taxroll1"
  self.primary_key  = "ID"

  has_one    :taxrollimage,                          primary_key: "accountnum", foreign_key: "AccountNum"
  has_one    :taxroll2,                              primary_key: "accountnum", foreign_key: "accountnum"
  has_one    :taxroll3,                              primary_key: "accountnum", foreign_key: "accountnum"
  has_one    :stat_county, class_name: "StatCounty", primary_key: "CountyID",   foreign_key: "CountyID"
  has_many   :file_properties,                       primary_key: "TaxID",      foreign_key: "serialnum"
  belongs_to :property,    class_name: 'Taxroll2',   primary_key: 'accountnum', foreign_key: 'accountnum'
  belongs_to :subdivision,                           primary_key: 'CountyID',   foreign_key: 'CountyID'
  belongs_to :county,                                primary_key: 'CountyID',   foreign_key: 'CountyID'
  belongs_to :recording_entry,                       primary_key: 'serialnum',  foreign_key: 'taxid'

  def taxroll2
    Taxroll2.where("accountnum = #{self.accountnum} AND CountyID = #{self.CountyID}").first
  end

  def taxroll3
    Taxroll3.where("accountnum = #{self.accountnum} AND CountyID = #{self.CountyID}").first
  end

  def address
    self.SitusAddress.nil? ? "" : self.SitusAddress
  end

  def city
    self.SitusCity.nil? ? "" : self.SitusCity
  end

  def zip
    self.SitusZipCode.nil? ? "" : self.SitusZipCode
  end
end
