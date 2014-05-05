class Taxroll2 < NewStatsBase
  self.table_name = "taxroll2"

  SELECT_OPTIONS = [
                    ["Acres","Acres"],
                    ["Account Number","accountnum"],
                    ["Balance Due","CollectionBalanceDue"],
                    ["Improvements","MarketValueImprovements"],
                    ["Land Value","MarketValueLand"],
                    ["Legal","FullLegal"],
                    ["Legal-STR","LegalDescriptionSequencer"],
                    ["Mailing Address","Address1"],
                    ["Owner Name","OwnerName"],
                    ["Site Address","SitusAddress"],
                    ["Subdivision Name","SubdivisionDescr"],
                    ["Taxable Value","TaxableValue"],
                    ["Tax ID","serialnum"]
                  ]

  SEARCH_DISPLAY = [
                    { label: 'Tax ID',          attribute: 'serialnum',               style: 'w100', format: 'to_s',     limit: 0,  to_link: false,  link_type: '' },
                    { label: 'Owner Name',      attribute: 'OwnerName',               style: 'w200', format: 'to_s',     limit: 15, to_link: true,   link_type: 'name' },
                    { label: 'Acres',           attribute: 'Acres',                   style: 'w100', format: 'to_s',     limit: 0,  to_link: false,  link_type: '' },
                    { label: 'Site Address',    attribute: 'SitusAddress',            style: 'w150', format: 'to_s',     limit: 15, to_link: false,  link_type: '' },
                    { label: 'Mailing Address', attribute: 'Address1',                style: 'w150', format: 'to_s',     limit: 15, to_link: false,  link_type: '' },
                    { label: 'Land Value',      attribute: 'MarketValueLand',         style: 'w150', format: 'currency', limit: 0,  to_link: false,  link_type: '' },
                    { label: 'Improvements',    attribute: 'MarketValueImprovements', style: 'w150', format: 'currency', limit: 0,  to_link: false,  link_type: '' },
                    { label: 'Taxable Value',   attribute: 'TaxableValue',            style: 'w150', format: 'currency', limit: 0,  to_link: false,  link_type: '' },
                    { label: 'Balance Due',     attribute: 'CollectionBalanceDue',    style: 'w100', format: 'currency', limit: 0,  to_link: false,  link_type: '' }
                  ]

  has_many   :images,      class_name: 'TaxrollImages', foreign_key: 'AccountNum',  primary_key: 'accountnum'
  has_one    :information, class_name: 'Taxroll3',      foreign_key: 'accountnum',  primary_key: 'accountnum'
  has_one    :assessment,  class_name: 'Taxroll1',      foreign_key: 'accountnum',  primary_key: 'accountnum'
  belongs_to :area,                                     foreign_key: 'CountyID',    primary_key: 'CountyID', inverse_of: :properties
  belongs_to :county,                                   foreign_key: 'CountyID',    primary_key: 'CountyID'
  belongs_to :taxroll1,                                 foreign_key: 'accountnum',  primary_key: 'accountnum'

  delegate :serialnum,               to: :assessment, prefix: false, allow_nil: true
  delegate :OwnerName,               to: :assessment, prefix: false, allow_nil: true
  delegate :Acres,                   to: :assessment, prefix: false, allow_nil: true
  delegate :SitusAddress,            to: :assessment, prefix: false, allow_nil: true
  delegate :Address1,                to: :assessment, prefix: false, allow_nil: true
  delegate :MarketValueLand,         to: :assessment, prefix: false, allow_nil: true
  delegate :MarketValueImprovements, to: :assessment, prefix: false, allow_nil: true
  delegate :TaxableValue,            to: :assessment, prefix: false, allow_nil: true
  delegate :CollectionBalanceDue,    to: :assessment, prefix: false, allow_nil: true

  def taxroll1
    Taxroll1.where("accountnum = #{self.accountnum} AND CountyID = #{self.CountyID}").first
  end

  def self.search(field,county,search)
    term = search.gsub("*","%")
    case field
    when "Acres"
      range = term.split(',')
      unless range[1].blank?
        joins(:assessment).where('Acres > ? AND Acres < ? AND taxroll2.CountyID = ?', range[0], range[1], county).order('accountnum')
      else
        joins(:assessment).where('Acres LIKE ? AND taxroll2.CountyID = ?', term + '%', county).order('accountnum')
      end
    when "accountnum"
      joins(:assessment).where('taxroll1.accountnum LIKE ? AND taxroll1.CountyID = ?', '%'+term+'%', county).order('taxroll1.OwnerName ASC')
    when "CollectionBalanceDue"
      range = term.split(',')
      unless range[1].blank?
        joins(:assessment).where('CollectionBalanceDue > ? AND CollectionBalanceDue < ? AND taxroll2.CountyID = ?', range[0], range[1], county).order('accountnum')
      else
        joins(:assessment).where('CollectionBalanceDue LIKE ? AND taxroll2.CountyID = ?', term + '%', county).order('accountnum')
      end
    when "MarketValueImprovements"
      range = term.split(',')
      unless range[1].blank?
        joins(:assessment).where('MarketValueImprovements > ? AND MarketValueImprovements < ? AND taxroll2.CountyID = ?', range[0], range[1], county).order('accountnum')
      else
        joins(:assessment).where('MarketValueImprovements LIKE ? AND taxroll2.CountyID = ?', term + '%', county).order('accountnum')
      end
    when "MarketValueLand"
      range = term.split(',')
      unless range[1].blank?
        joins(:assessment).where('MarketValueLand > ? AND MarketValueLand < ? AND taxroll2.CountyID = ?', range[0], range[1], county).order('accountnum')
      else
        joins(:assessment).where('MarketValueLand LIKE ? AND taxroll2.CountyID = ?', term + '%', county).order('accountnum')
      end
    when "FullLegal"
      where('FullLegal LIKE ? AND CountyID = ?', term + '%', county).order('accountnum')
    when "LegalDescriptionSequencer"
      where('LegalDescriptionSequencer LIKE ? AND CountyID = ?', term + '%', county).order('accountnum')
    when "Address1"
      joins(:assessment).where('Address1 LIKE ? AND taxroll2.CountyID = ?', term + '%', county).order('accountnum')
    when "OwnerName"
      joins(:assessment).where('OwnerName LIKE ? AND taxroll2.CountyID = ?', term.gsub("'", "\\\\'") + '%', county).order('OwnerName ASC')
    when "SitusAddress"
      joins(:assessment).where('SitusAddress LIKE ? AND taxroll2.CountyID = ?', term + '%', county)
    when "Subdivision Name"
      joins(:information).where('SubdivisionDescr LIKE ? AND taxroll3.CountyID = ?', term + '%', county).order('accountnum')
    when "serialnum"
      joins(:assessment).where('taxroll1.serialnum LIKE ? AND taxroll1.CountyID = ?', term + '%', county).order('taxroll1.serialnum')
    when "TaxableValue"
      joins(:assessment).where('TaxableValue LIKE ? AND taxroll2.CountyID = ?', term + '%', county).order('accountnum')
    else
      where('CountyID = ?', county).order('accountnum')
    end
  end

  def get_coords
    TaxLatLong.where('tax_id = ? AND county_id = ?', self.serialnum.to_s, self.CountyID).first
  end

end
