class County < ActiveRecord::Base
  self.table_name  = "tblCounty"
  self.primary_key = "CountyID"

  default_scope { order("CountyName ASC") }

  has_many   :companies_im_default_for, class_name: "Company",    foreign_key: "DefaultCounty",  primary_key: "CountyID", order: "CompanyID"
  has_many   :entities,                                           foreign_key: "CountyID",       primary_key: "CountyID", order: "EntityID"
  has_many   :files,                    class_name: "FileInfo",   foreign_key: "CountyID",       primary_key: "CountyID", order: "CompanyID, FileID"
  has_many   :file_properties,                                    foreign_key: "CountyID",       primary_key: "CountyID", order: "FileID, ID"
  has_many   :offices,                                            foreign_key: "CountyID",       primary_key: "CountyID", order: "ID"
  has_many   :vendor_trak_file_infos,                             foreign_key: "CountyID",       primary_key: "CountyID", order: "id"
  has_many   :doc_templates,                                      foreign_key: "county_id",      primary_key: "CountyID"
  belongs_to :payee,                    class_name: "Entity",     foreign_key: "PayeeID",        primary_key: "EntityID"
  belongs_to :state,                                              foreign_key: "StateID",        primary_key: "ID"
  has_many   :areas,                                              foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :properties,                                         foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :assessments,                                        foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :subdivisions,                                       foreign_key: 'County',         primary_key: 'CountyID'
  has_many   :recording_entries,                                  foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_entry_affiliations,                       foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_koi,                                      foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_legal,                                    foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_name,                                     foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_section,                                  foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_subdivision,                              foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :recording_taxid,                                    foreign_key: 'CountyID',       primary_key: 'CountyID'
  has_many   :fp_standard_requirements

  has_and_belongs_to_many :regions, join_table: "regions_counties" # Join table in filetrak, has no Model, also no migration

  def self.id_collection
    self.find(:all).collect{|c| [c.CountyName, c.CountyID]}
  end

   def self.name_collection
    self.find(:all).collect{|c| [c.CountyName, c.CountyName]}
  end
end
