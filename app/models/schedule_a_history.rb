class ScheduleAHistory < ActiveRecord::Base
  self.table_name  = "tblScheduleAHistory"
  self.primary_key = "ID"

  belongs_to :file_info,             :foreign_key => "FileID", :primary_key => "FileID"
  belongs_to :vendor_trak_file_info, :foreign_key => "FileID", :primary_key => "FileID"
  belongs_to :modified_by, :class_name => "Employee", :foreign_key => "ModifiedBy", :primary_key => "ID" # ModifiedDT

  #
  # Quick access method for grabbing the value of a specific field in a
  # specific product in a specific file (grabs most-recently-created value for
  # the field). Returns the value, if found, as a string. Otherwise returns
  # nil. If the field DOES HAVE a value of the empty string ("") then this will
  # be returned AS IS with no coercing to nil.
  #
  def self.value(file_or_id, product, field)
    file_or_id = file_or_id.id if file_or_id.is_a?(FileInfo)
    result     = self.find_by_FileID_and_Product_and_FieldName(
      file_or_id, product, field, :order => "ID DESC", :limit => 1
      )
    return nil unless result
    result.FieldValue
  end

end
