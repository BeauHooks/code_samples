class Requirement < ActiveRecord::Base
  self.table_name  = "tblRequirements"

  default_scope {where("tblRequirements.Show != 0 AND ReqType != 'Standard'").order("RequirementNum ASC")}

  belongs_to :index, foreign_key: "FileID", primary_key: "FileID"

  def content
    self.RequirementText.to_s.gsub(/\n/, "<br />").html_safe
  end

  def schedule_b_exception
    ScheduleBException.where("FileID = #{self.FileID} AND Product = '#{self.Product}' AND ExceptionNum = '#{self.ExceptionNum}'").first
  end
end
