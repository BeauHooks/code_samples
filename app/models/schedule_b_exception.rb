class ScheduleBException < ActiveRecord::Base
	self.table_name  = "tblScheduleBExceptions"
  self.primary_key = "ID"

  default_scope {where("ExceptionRemovedDT IS NULL AND ModifiedDT < '#{Time.now}'").group("ExceptionUniqueID").order("ExceptionNum ASC, ModifiedDT ASC")}

  def requirements
    Requirement.where("ExceptionUniqueID = #{self.ExceptionUniqueID}")
  end
end