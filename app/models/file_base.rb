class FileBase < ActiveRecord::Base
  self.table_name  = "tblBases"
  self.primary_key = "BaseID"

  default_scope{ where("NewGoodBase != 0").order("Subsurvey, Phase") }

  belongs_to :county,          primary_key: "CountyID", foreign_key: "CountyID"
  has_many   :file_exceptions, primary_key: "BaseID",   foreign_key: "BaseID"

  def file_exceptions
  	true_exceptions = Hash.new
  	exceptions = []

  	super().each do |exception|
  		true_exceptions[exception.RealNum] = exception
  	end

  	true_exceptions.each do |key, exception|
  		exceptions << exception
  	end
  	exceptions
  end
end