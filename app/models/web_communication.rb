class WebCommunication < ActiveRecord::Base
  self.table_name  	= "tblWebCommunication"
  self.primary_key 	= "WebComID"

  belongs_to :employee,              foreign_key: "EmployeeID",   primary_key: "ID"
  belongs_to :file_info,             foreign_key: "FileID",       primary_key: "FileID"
  belongs_to :vendor_trak_file_info, foreign_key: "FileID",       primary_key: "FileID"
  belongs_to :underwriter,           foreign_key: "Underwriter",  primary_key: "ID"
  has_one    :rate_calculation,                                      primary_key: "WebComID"

  # Return the associated RateCalculation object. If there isn't one yet
  # associated, create, associate, and initialize it and then return it.
  #
  def initialized_rate_calculation
    return rate_calculation if rate_calculation

    # Convert the "mode" field to the version we use internally
    mode = case self.OpenArgs
      when "QUOTE" then "quote"
      when "HUD"   then "hud"
      when "PR"    then "pr"
      when "POL1"  then "policy_1"
      when "POL2"  then "policy_2"
      else              "default"
    end

    # Create our new RateCalculation instance
    self.build_rate_calculation(
      :underwriter_id       => self.UnderwriterID,
      :company_id           => self.FileID.to_s[0..2].to_i,
      :employee_id          => self.EmployeeID,
      :file_info_id         => self.FileID,
      :product_name         => self.ProductName,
      :mode                 => mode
      )
  end
end
