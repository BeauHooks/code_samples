class FileProperty < ActiveRecord::Base
  self.table_name  = "tblFileProperties"
  self.primary_key = "ID"

  before_save :update_related
  after_save :update_convienence_fields

  IMPORT_FROM = { 1 => "TODO", 2 => "TODO", 3 => "TODO" }

  belongs_to :county,                               foreign_key: "CountyID",     primary_key: "CountyID"
  belongs_to :file_info,                            foreign_key: "FileID",       primary_key: "FileID"
  belongs_to :index,                                foreign_key: "index_id",     primary_key: "ID"
  belongs_to :vendor_trak_file_info,                foreign_key: "FileID",       primary_key: "FileID"
  belongs_to :prior_file,  class_name: "FileInfo",  foreign_key: "PriorFile",    primary_key: "FileID"
  belongs_to :taxroll1,    class_name: "Taxroll1",  foreign_key: "TaxID",        primary_key: "serialnum"

  # Employee Action-Tracking Relationships
  belongs_to :searched_by, class_name: "Employee",  foreign_key: "SearchedBy",   primary_key: "ID"

  scope :active, conditions: { Inactive: 0 }

  def update_related
    if self.PropertyCheckedBy_changed?
      self.PropertyCheckedDT = Time.now.to_s(:db)
    end
  end

  def property_checked_by
    Employee.find(self.PropertyCheckedBy).FullName
  rescue
    "NULL"
  end

  def exists_in_taxroll?
    if Taxroll1.find_by_serialnum(self.TaxID)
      true
    else
      false
    end
  end

  def full_address
    address = []
    address << self.PropertyAddress unless self.PropertyAddress.blank?
    address << self.City unless self.City.blank?
    address << self.State unless self.State.blank?
    address = [address.join(", ")]
    address << self.Zip unless self.Zip.blank?
    address = address.join(" ")
  end

  private

  def update_convienence_fields
    file = self.index

    if self.Inactive?
      if self.TaxID == file.TaxID1
        file.TaxID1   = nil
        file.Address1 = nil
        file.Legal1   = nil
      end
      property = file.file_properties.active.first
      if !property.nil?
        file.TaxID1   = property.TaxID
        file.Address1 = property.PropertyAddress
        file.Legal1   = property.LegalDescription
      end
    else
      if file.TaxID1 == nil
        file.TaxID1   = self.TaxID
        file.Address1 = self.PropertyAddress
        file.Legal1   = self.LegalDescription
      else
        properties = []
        file.file_properties.active.each {|p| properties << p.TaxID}
        if !properties.include?(file.TaxID1)
          file.TaxID1   = self.TaxID
          file.Address1 = self.PropertyAddress
          file.Legal1   = self.LegalDescription
        end
      end
    end
    file.save!
  end
end
