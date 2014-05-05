class ScheduleAOld < ActiveRecord::Base
  self.table_name  = "tblScheduleA"

  default_scope { where("EffectiveDT IS NOT NULL AND EffectiveDate IS NOT NULL").order("EffectiveDT ASC") }

  belongs_to :file_info,             foreign_key: "FileID",   primary_key: "FileID"
  belongs_to :vendor_trak_file_info, foreign_key: "FileID",   primary_key: "FileID"
  has_one    :underwriter,           foreign_key: "ID",       primary_key: "UnderWriterID"

  def use_exhibit_a?
    !self.UseExhibitA.zero?
  end

  def underwriter_name
    self.underwriter.Underwriter rescue ""
  end
end
