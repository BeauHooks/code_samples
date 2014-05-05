class VendorTrakFileInfo < ActiveRecord::Base
  self.table_name  	= "tblVTFileInfo"
  self.primary_key 	= "id"

  belongs_to :county,                     foreign_key: "CountyID", primary_key: "CountyID"
  belongs_to :file_info,                  foreign_key: "FileID",   primary_key: "FileID"
  has_many   :file_images,                foreign_key: "FileID",   primary_key: "FileID", order: "ImageType, ImageDate, ImageID"
  has_many   :file_notes,                 foreign_key: "FileID",   primary_key: "FileID", order: "NoteID"
  has_many   :file_products,              foreign_key: "FileID",   primary_key: "FileID", order: "ProductName, IsActive, DummyTime DESC"
  has_many   :file_properties,            foreign_key: "FileID",   primary_key: "FileID", order: "ID"
  has_many   :vendor_trak_file_borrowers, foreign_key: "FileID",   primary_key: "FileID", order: "id"
  has_many   :schedule_a_old_histories,   foreign_key: "FileID",   primary_key: "FileID", order: "Product, FieldName, ID DESC"
  has_many   :rate_calculations,                                   primary_key: "FileID", order: "employee_id, created_at"
  has_many   :web_communications,         foreign_key: "FileID",   primary_key: "FileID", order: "DummyTime"

end
