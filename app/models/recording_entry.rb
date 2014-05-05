class RecordingEntry < NewStatsBase
  self.table_name   = "tblUTEntry"
  self.primary_key  = "ID"

  SELECT_OPTIONS = [
                    ["Book-Page","Book-Page"],
                    ["Consideration","consideration"],
                    ["Entry Number","entrynumber"],
                    ["Grantee","toparty"],
                    ["Grantor","fromparty"],
                    ["Grantor - Grantee","fromparty-toparty"],
                    ["Lot","lot"],
                    ["Recorded For","recordedfor"],
                    ["Sect-Town-Range","section-township-range"],
                    ["Subsurvey","subsurvey"],
                    ["Tax ID","taxid"],
                    ["Type (KOI)","koi"],
                    ["Recons Not Affiliated","IsSUTCEntry"]
                  ]

  SEARCH_DISPLAY = [
                    { label: 'Entry Number', attribute: 'entrynumber',       style: 'w150', format: 'round',        limit: 0,  to_link: true,  link_type: 'recording_entry' },
                    { label: 'Recorded',     attribute: 'filingdate',        style: 'w150', format: 'date',         limit: 0,  to_link: false, link_type: '' },
                    { label: 'Tax ID',       attribute: 'taxid',             style: 'w100', format: 'to_s',         limit: 0,  to_link: false, link_type: '' },
                    { label: 'Type',         attribute: 'type',              style: 'w100', format: 'to_s',         limit: 0,  to_link: false, link_type: '' },
                    { label: 'From Party',   attribute: 'fromparty',         style: 'w200', format: 'to_s',         limit: 15, to_link: false, link_type: '' },
                    { label: 'To Party',     attribute: 'toparty',           style: 'w200', format: 'to_s',         limit: 15, to_link: false, link_type: '' },
                    { label: 'Recorded For', attribute: 'recordedfor',       style: 'w200', format: 'to_s',         limit: 15, to_link: false, link_type: '' },
                    { label: 'Amount',       attribute: 'consideration',     style: 'w100', format: 'currency',     limit: 0,  to_link: false, link_type: '' },
                    { label: 'Acres',        attribute: 'Acres',             style: 'w100', format: 'to_s',         limit: 0,  to_link: false, link_type: '' },
                    { label: 'Valuation',    attribute: 'TotalValuation',    style: 'w100', format: 'currency',     limit: 0,  to_link: false, link_type: '' }
                  ]

  belongs_to :recording_koi,                                                  foreign_key: 'koi',         primary_key: 'koi'
  has_many   :recording_sections,                                             foreign_key: 'EntryNum',    primary_key: 'entrynumber'
  has_many   :recording_names,                                                foreign_key: 'EntryNum',    primary_key: 'entrynumber'
  belongs_to :recording_name,                                                 foreign_key: 'EntryNum',    primary_key: 'entrynumber'
  has_many   :recording_taxids,                                               foreign_key: 'EntryNumber', primary_key: 'entrynumber'
  belongs_to :taxid_entry,         class_name: 'RecordingTaxid',              foreign_key: 'EntryNumber', primary_key: 'entrynumber'
  has_many   :recording_subdivisions,                                         foreign_key: 'EntryNum',    primary_key: 'entrynumber'
  has_many   :recording_legals,                                               foreign_key: 'EntryNum',    primary_key: 'entrynumber'
  belongs_to :county,                                                         foreign_key: 'CountyID',    primary_key: 'CountyID'
  has_many   :first_entries,       class_name: 'RecordingEntryAffiliation',   foreign_key: 'FirstNum',    primary_key: 'entrynumber'
  has_many   :second_entries,      class_name: 'RecordingEntryAffiliation',   foreign_key: 'SecondNum',   primary_key: 'entrynumber'
  belongs_to :first_entry,         class_name: 'RecordingEntryAffiliation',   foreign_key: 'FirstNum',    primary_key: 'entrynumber'
  belongs_to :second_entry,        class_name: 'RecordingEntryAffiliation',   foreign_key: 'SecondNum',   primary_key: 'entrynumber'
  has_one    :assessment,          class_name: 'Taxroll1',                    foreign_key: 'serialnum',   primary_key: 'taxid'
  has_many   :recording_names,                                                foreign_key: 'EntryNum',    primary_key: 'entrynumber'
  has_many   :recording_froms,     class_name: 'RecordingName',               foreign_key: 'EntryNum',    primary_key: 'entrynumber', conditions: "FromToFlag = 'F'"
  has_many   :recording_tos,       class_name: 'RecordingName',               foreign_key: 'EntryNum',    primary_key: 'entrynumber', conditions: "FromToFlag = 'T'"
  belongs_to :reference,           class_name: 'RecordingEntry',              foreign_key: 'RefEntryNum', primary_key: 'entrynumber'

  delegate :type,           to: :recording_koi, prefix: false, allow_nil: true
  delegate :Acres,          to: :assessment,    prefix: false, allow_nil: true
  delegate :TotalValuation, to: :assessment,    prefix: false, allow_nil: true

  def self.search(field,county,search,date_from,date_to)
    unless date_to.blank?
      d_to = date_to.split('/')
      date_to = Date.new(d_to[2].to_i,d_to[0].to_i,d_to[1].to_i).to_datetime
    else
      date_to = DateTime.now.midnight
    end
    unless date_from.blank?
      d_from = date_from.split('/')
      date_from = Date.new(d_from[2].to_i,d_from[0].to_i,d_from[1].to_i).to_datetime
    else
      date_from = DateTime.now - 50.years
    end
    term = search.gsub("*","%")
    case field
    when "fromparty-toparty"
      ids = RecordingName.joins(:recording_entry).where('RecordationName LIKE ? AND tblUTNames.CountyID = ? AND tblUTEntry.filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).group(:EntryNum).pluck(:EntryNum)
      where(:entrynumber => ids, CountyID: county).order('entrynumber DESC')
    when "section-township-range"
      range = term.split('-')
      unless range[1].blank?
        where('section LIKE ? AND township LIKE ? AND range LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', range[0]+'%', range[1]+'%', range[2]+'%', county, date_from, date_to).order('entrynumber DESC')
      else
        where('section LIKE ? OR township LIKE ? OR range LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term+'%', term+'%', term+'%', county, date_from, date_to).order('entrynumber DESC')
      end
    when "Book-Page"
      range = term.split('-')
      unless range[1].blank?
        where('Book LIKE ? AND Page LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', range[0]+'%', range[1]+'%', county, date_from, date_to).order('entrynumber DESC')
      else
        where('Book LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', '%'+term+'%', county, date_from, date_to).order('entrynumber DESC')
      end
    when "consideration"
      range = term.split(',')
      unless range[1].blank?
        where('consideration > ? AND consideration < ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', range[0], range[1], county, date_from, date_to).order('entrynumber DESC')
      else
        where('consideration LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).order('entrynumber DESC')
      end
    when "entrynumber"
      where('entrynumber BETWEEN ? AND ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term.to_i - 25, term.to_i + 24, county, date_from, date_to).order('entrynumber DESC')
    when "IsSUTCEntry"
      where('IsSUTCEntry LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).order('entrynumber DESC')
    when "subsurvey"
      where('subsurvey LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).order('entrynumber DESC')
    when "koi"
      joins(:recording_koi).where('type LIKE ? AND tblUTEntry.CountyID = ? AND tblUTEntry.filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).order('entrynumber DESC')
    when "taxid"
      taxids = RecordingTaxid.joins(:taxid_entry).where('tblUTTaxID.TaxID LIKE ? AND tblUTTaxID.CountyID = ? AND tblUTEntry.filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).group(:EntryNumber).pluck(:EntryNumber)
      where(:entrynumber => taxids, CountyID: county).order('entrynumber DESC')
    when "recordedfor"
      where('recordedfor LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).order('entrynumber DESC')
    when "toparty"
      ids = RecordingName.joins(:recording_entry).where('RecordationName LIKE ? AND tblUTNames.FromToFlag = ? AND tblUTNames.CountyID = ? AND tblUTEntry.filingdate BETWEEN ? AND ?', term+'%', 'T', county, date_from, date_to).group(:EntryNum).pluck(:EntryNum)
      where(:entrynumber => ids, CountyID: county).order('entrynumber DESC')
    when "fromparty"
      ids = RecordingName.joins(:recording_entry).where('RecordationName LIKE ? AND tblUTNames.FromToFlag = ? AND tblUTNames.CountyID = ? AND tblUTEntry.filingdate BETWEEN ? AND ?', term+'%', 'F', county, date_from, date_to).group(:EntryNum).pluck(:EntryNum)
      where(:entrynumber => ids, CountyID: county).order('entrynumber DESC')
    when "lot"
      where('lot LIKE ? AND CountyID = ? AND filingdate BETWEEN ? AND ?', term+'%', county, date_from, date_to).order('entrynumber DESC')
    else
      where('CountyID = ? filingdate BETWEEN ? AND ?', county, date_from, date_to).order('entrynumber DESC')
    end
  end

  def get_file
    entry = self.entrynumber.to_i.to_s
    if entry.length == 11
      file = File.join(DriveMap.map("k") + "/WashCo/#{entry[0..3]}/#{entry[6..7].to_i}/#{entry}.TIF")
    elsif entry.length == 6
      file = File.join(DriveMap.map("k") + "/WashCo/#{entry[0..2]}/#{entry}.TIF")
    end
    return false unless Pathname.new(file).exist?
    file
  end

end
