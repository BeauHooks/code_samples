class Check < DisburseBase
  self.table_name  = "tblCheck"
  self.primary_key = "ID"

  # Return only checks ready to be printed for the specified companies. If no
  # company or list of companies is specified, checks for all companies will be
  # returned. Companies may be specified by passing a Company instance or the
  # company ID number.
  #
  scope :printable, lambda { |companies|
    companies = [ companies ].flatten.map do |c|
      c.is_a?(Company) ? c.CompanyID : c
    end.reject { |c| c.to_s !~ /^\d+$/ }
    result = {
      :conditions => {
        :CheckPrinted => false,
        :Void         => false,
        :CheckNo      => nil,
        :IsApproved   => true
      },
      :order => "FileID, FundsType DESC, ID DESC"
    }
    result[:conditions][:CompanyID] = companies.map { |c| c.to_i } unless companies.empty?
    result
  }

  scope :unheld, :conditions => ['Hold NOT LIKE ?', '%h%']

  belongs_to :company,           foreign_key: "CompanyID",   primary_key: "CompanyID"
  belongs_to :employee,          foreign_key: "EmployeeID",  primary_key: "ID"
  belongs_to :office,            foreign_key: "PrintOffice", primary_key: "ID"
  belongs_to :file_info,         foreign_key: "FileID",      primary_key: "FileID"
  has_many   :wire_out_details,  foreign_key: "WireID",      primary_key: "ID",    order: "WireDT"
  has_many   :hud_line_payments, foreign_key: "check_id",    primary_key: "ID"

  # The "company" may be a Company instance or a company id number. This method
  # returns the next available check number for use by the specified company.
  # You may optionally provide the starting check number if you suspect that no
  # checks yet exist for the specified company (defaults to 100). If the
  # provided "company" isn't a valid Company instance or comapny id, an
  # exception will be raised.
  #
  # NOTE: This does a simple database lookup so race conditions apply!
  #
  def self.next(company, start = 100)
    company = Company.find(company) unless company.is_a?(Company) rescue nil
    raise ArgumentError, "Invalid company for check number lookup: (#{company.class}) #{company}" unless company
    result   = maximum('CheckNo', :conditions => { :FundsType => 'check', :CompanyID => company.CompanyID })
    result ||= start - 1
    result + 1
  end

  # Returns true if the specified check number has been used for the specified
  # company. The "company" parameter may be a Company instance or a company id.
  #
  def self.used?(company, number)
    company = Company.find(company) unless company.is_a?(Company) rescue nil
    raise ArgumentError, "Invalid company for check number lookup: (#{company.class}) #{company}" unless company
    !!find_by_FundsType_and_CompanyID_and_CheckNo('check', company.CompanyID, number)
  end

  # Shortcut method that returns the printer name, if any, associated with the
  # office, if any, that is associated with this check. Returns nil if no
  # office or printer is associated.
  #
  def printer
    return nil unless self.office and self.office.HasPrinter
    self.office.PrinterName
  end
end
