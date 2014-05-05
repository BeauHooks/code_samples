class FileProductOld < ActiveRecord::Base
  self.table_name = "tblFileProducts"
  self.primary_key = "ID"

  default_scope{ where("IsActive != 0") }

  belongs_to :index, primary_key: "FileID", foreign_key: "FileID"

  def schedule_b_exceptions
    true_exceptions = Hash.new
    all_exceptions = ScheduleBException.find(:all, conditions: ["FileID = #{self.FileID} AND Product = '#{self.ProductName}'"])

    all_exceptions.each do |exception|
      true_exceptions[exception.ExceptionNum] = exception
    end

    exceptions = []
    true_exceptions.each do |key, object|
      exceptions << object
    end
    exceptions
  end

  def schedule_a_old
    ScheduleAOld.where("FileID = #{self.FileID} AND Product = '#{self.ProductName}'").first
  end

  def requirements
    Requirement.where("FileID = #{self.FileID} AND Product = '#{self.ProductName}'")
  end
end
