class ClosingProtectionLetter < ActiveRecord::Base

  belongs_to :file,         class_name: 'Index',      foreign_key: 'index_id',       primary_key: 'ID'
  belongs_to :company,                                foreign_key: 'company_id',     primary_key: 'CompanyID'
  belongs_to :created_by,   class_name: 'User',       foreign_key: 'created_by',     primary_key: 'id'
  belongs_to :updated_by,   class_name: 'User',       foreign_key: 'updated_by',     primary_key: 'id'
  belongs_to :cpl_sent_by,  class_name: 'User',       foreign_key: 'cpl_sent_by',    primary_key: 'id'
  has_many   :file_images,                            foreign_key: "FileID",         primary_key: "File_id"
  belongs_to :current_cpl,  class_name: 'FileImage',  foreign_key: "file_image_id",  primary_key: "ImageID"
  belongs_to :closer,       class_name: "Employee",   foreign_key: "closer_id",      primary_key: "ID"
  belongs_to :lender,       class_name: "Entity",     foreign_key: "lender_id",      primary_key: "EntityID"

  delegate :agent_number,       to: :file, prefix: false, allow_nil: true
  delegate :authorization_code, to: :file, prefix: false, allow_nil: true
  delegate :underwriter,        to: :file, prefix: false, allow_nil: true
  delegate :borrowers,          to: :file, prefix: false, allow_nil: true
  delegate :buyers,             to: :file, prefix: false, allow_nil: true
  delegate :DisplayFileID,      to: :file, prefix: false, allow_nil: true
  delegate :FileID,             to: :file, prefix: false, allow_nil: true
  delegate :file_entities,      to: :file, prefix: false, allow_nil: true

  def post_xml(path, xml)
    host = "https://AgentNetWs.Ext.Firstam.com"
    http = Net::HTTP.new(host)
    resp = http.post(path, xml, { 'Content-Type' => 'application/soap+xml; charset=utf-8' })
    return resp.body
  end

  def client_old_republic(path, xml)
    client = Typhoeus::Request.new do
      # test service
      wsdl "https://quawscplrq-lb.oldrepublictitle.com/cplws-2/GenericCPLService.svc?wsdl"
      #live service
      # wsdl "https://wscplrq.oldrepublictitle.com/cplws-2/GenericCPLService.svc?wsdl"
      operations :get_lookup_data, :find_cpl_by_order_number, :close_cpl, :cancel_cpl, :update_cpl, :submit_cpl_order
    end
    client
  end

  def client_first_american
    client = Typhoeus::Request.new (
      endpoint: 'https://AgentNetWs.Ext.Firstam.com/ThirdParty/AgentNetWS.svc'.
      namespace: 'https://AgentNetWs.Ext.Firstam.com'
    )
    client
  end

  def borrower_array
    borrower_array = []
    self.borrowers.each do |borrower|
      borrower_array << "#{borrower.entity.FirstName} #{borrower.entity.LastName}"
    end
    borrower_array
  end

  def cpl_gather_data(file)
    self.letter_type       = "ALTA8"
    self.transaction_state = "UT"
    unless file.lender.blank?
      self.lender                  = file.lender
      self.lender_name             = file.lender.FullName
      self.lender_contact_name     = file.lender.primary_employee_name
      self.lender_telephone_number = file.lender.primary_phone_number.gsub("Work: ","")
      self.lender_fax_number       = file.lender.FaxNum
      self.lender_email_address    = file.lender.Email
      unless file.lender.entity_contacts.empty?
        self.lender_address_line_1 = file.lender.entity_contacts.first.Address
        self.lender_address_line_2 = file.lender.entity_contacts.first.Address2
        self.lender_city           = file.lender.entity_contacts.first.City
        self.lender_state          = file.lender.entity_contacts.first.State
        self.lender_zip_code       = file.lender.entity_contacts.first.Zip
      end
    end
    unless file.file_properties.empty?
      self.property_street_address = file.file_properties.first.PropertyAddress
      self.property_city           = file.file_properties.first.City
      self.property_zip            = file.file_properties.first.Zip
    end
    self.pertains_to = file.borrower_names
    unless file.closer.blank?
      self.closer       = file.closer
      self.closer_name  = file.closer.FullName
      self.closer_phone = file.closer.DirectPhone
      self.closer_email = file.closer.Email
      self.closer_fax   = file.closer.DirectFax
    end
    self.save
  end

  def cpl_update_data(file)
    if self.lender != file.lender && !file.lender.blank?
      self.lender                  = file.lender
      self.lender_name             = file.lender.FullName
      self.lender_contact_name     = file.lender.primary_employee_name
      self.lender_telephone_number = file.lender.primary_phone_number.gsub("Work: ","")
      self.lender_fax_number       = file.lender.FaxNum
      self.lender_email_address    = file.lender.Email
      self.lender_address_line_1   = file.lender.entity_contacts.first.Address
      self.lender_address_line_2   = file.lender.entity_contacts.first.Address2
      self.lender_city             = file.lender.entity_contacts.first.City
      self.lender_state            = file.lender.entity_contacts.first.State
      self.lender_zip_code         = file.lender.entity_contacts.first.Zip
    end
    if self.closer != file.closer && !file.closer.blank?
      self.closer       = file.closer
      self.closer_name  = file.closer.FullName
      self.closer_phone = file.closer.DirectPhone
      self.closer_email = file.closer.Email
      self.closer_fax   = file.closer.DirectFax
    end
    self.save
  end

  def save_cpl_pdf(response,random_string)
    file_image               = FileImage.new
    file_image.FileID        = self.FileID
    file_image.DisplayFileID = self.DisplayFileID
    file_image.ImageType     = "CPL"
    file_image.ImageDate     = Time.now.to_s(:db)
    file_image.EnteredBy     = self.cpl_sent_by.employee_id
    file_image.ImageNotes    = "CPL REF ##{self.id}"
    tempfile                 = random_string + "_file"
    file_image.tempfile      = tempfile
    str                      = response[:cpl_document_base64]
    pdf                      = Base64.decode64(str)
    prefix                   = self.DisplayFileID.to_i / 1000
    full_file_path           = "F:\\images\\#{self.company.DirName}\\cpl\\#{prefix.to_s}\\#{self.DisplayFileID}\\#{self.letter_reference_number}.pdf".downcase
    file_image.FullFileName  = full_file_path
    file_image.save

    file = "#{Rails.root}/tmp/process_images/#{tempfile}.pdf"
    process_file = File.open(file, 'wb')
    process_file.write(pdf)
    file2 = "#{Rails.root}/tmp/cpl/#{tempfile}.pdf"
    tmp_file = File.open(file2, 'wb')
    tmp_file.write(pdf)

    if self.current_cpl.present?
      self.current_cpl.update_attributes(:Inactive => -1)
    end

    self.update_attributes(current_cpl: file_image)
  end

  def unknown?;  self.cpl_status == "Unknown"  end
  def active?;   self.cpl_status == "Active"   end
  def canceled?; self.cpl_status == "Canceled" end
  def closed?;   self.cpl_status == "Closed"   end
  def updated?;  self.cpl_status == "Updated"  end
  def open?;     self.cpl_status != "Canceled" end

  def cpl_sent?
    !self.cpl_updated_at.nil?
  end

  def valid_to_send?
    errors.add(:cpl_status, "CPL has been Canceled") if self.canceled?
    errors.add(:cpl_status, "CPL has been Closed") if self.closed?
    errors.add(:file_id, "Cannot be Blank") if self.file.blank?
    errors.add(:pertains_to, "Cannot be Blank") if self.pertains_to.blank?
    errors.add(:letter_type, "Cannot be Blank") if self.letter_type.blank?
    errors.add(:company_id, "Cannot be Blank") if self.company_id.blank?
    errors.add(:property_street_address, "Cannot be Blank") if self.property_street_address.blank?
    errors.add(:property_city, "Cannot be Blank") if self.property_city.blank?
    errors.add(:property_zip, "Cannot be Blank") if self.property_zip.blank?
    errors.add(:transaction_state, "Cannot be Blank") if self.transaction_state.blank?
    errors.add(:lender_name, "Cannot be Blank") if self.lender_name.blank?
    errors.add(:closer_id, "Cannot be Blank") if self.closer_id.blank?
    errors.add(:lender_address_line_1, "Cannot be Blank") if self.lender_address_line_1.blank?
    errors.add(:lender_state, "Cannot be Blank") if self.lender_state.blank?
    errors.add(:lender_city, "Cannot be Blank") if self.lender_city.blank?
    errors.add(:lender_zip_code, "Cannot be Blank") if self.lender_zip_code.blank?
    errors.add(:can_resubmit_current, "Cannot be Blank") if self.can_resubmit_current == false
    self.errors.empty?
  end

  def fatco_validate_login
    message = {
      "LoginAccountIdentifier" => "dev_sutc",
      "LoginAccountPasswordText" => "abc123"
    }
    response = client_first_american.call(:AGENTNET_GET_DATA) do
      message message
    end
  end

  def get_lookup_data
    message = {
      "tns:agentNumber"       => self.agent_number,
      "tns:authorizationCode" => self.authorization_code,
      "tns:propertyStateCode" => self.transaction_state
    }
    response = client_old_republic.call(:get_lookup_data) do
      message message
    end
    response.body[:get_lookup_data_response][:get_lookup_data_result][:lookup_data]
  end

  def find_cpl_by_order_number
    message = {
      "tns:agentNumber"       => self.agent_number,
      "tns:authorizationCode" => self.authorization_code,
      "tns:originatorOrderID" => self.DisplayFileID
    }
    response = client_old_republic.call(:find_cpl_by_order_number) do
      message message
    end
    response.body
  end

  def close_cpl
    message = {
      "tns:agentNumber"       => self.agent_number,
      "tns:authorizationCode" => self.authorization_code,
      "tns:referenceNumber"   => self.letter_reference_number
    }
    response = client_old_republic.call(:close_cpl) do
      message message
    end
    response.body[:close_cpl_response][:close_cpl_result]
  end

  def cancel_cpl
    message = {
      "tns:agentNumber"       => self.agent_number,
      "tns:authorizationCode" => self.authorization_code,
      "tns:referenceNumber"   => self.letter_reference_number
    }
    response = client_old_republic.call(:cancel_cpl) do
      message message
    end
    response.body[:cancel_cpl_response][:cancel_cpl_result]
  end

  def update_cpl
    message = {
      "tns:agentNumber"          => self.agent_number,
      "tns:authorizationCode"    => self.authorization_code,
      "tns:referenceNumber"      => self.letter_reference_number,
      "tns:closingMarketOrderID" => self.id,
      "tns:originatorOrderID"    => self.DisplayFileID,
      "tns:orderData"            => {
        "tns:AgentContactName"                               => self.closer_name,
        "tns:AgentContactPhone"                              => self.closer_phone,
        "tns:AgentContactFax"                                => self.closer_fax,
        "tns:DeliverToAgentViaFax"                           => 0,
        "tns:AgentContactEmail"                              => self.closer_email,
        "tns:DeliverToAgentViaEmail"                         => 0,
        "tns:Borrowers"                                      => { "tns:arr" => self.borrower_array },
        "tns:Buyers"                                         => { "tns:arr" => [] },
        "tns:BranchOfficeID"                                 => "",
        "tns:IncludeBranchOfficeOnThisLetter"                => 0,
        "tns:IncludeAllOfTheAgencyBranchOfficesOnThisLetter" => 0,
        "tns:ClosingAttorneyID"                              => "",
        "tns:ClosingAttorneyFaxNumber"                       => "",
        "tns:DeliverToClosingAttorneyViaFax"                 => 0,
        "tns:Lender"                                         => {
          "tns:Name"            => self.lender_name,
          "tns:NameContinued"   => "",
          "tns:ContactName"     => self.lender_contact_name,
          "tns:AddressLine1"    => self.lender_address_line_1,
          "tns:AddressLine2"    => self.lender_address_line_2,
          "tns:City"            => self.lender_city,
          "tns:State"           => self.lender_state,
          "tns:ZipCode"         => self.lender_zip_code,
          "tns:TelephoneNumber" => self.lender_telephone_number,
          "tns:FaxNumber"       => self.lender_fax_number,
          "tns:EmailAddress"    => self.lender_email_address
        },
        "tns:DeliverToLenderViaEmail" => 0,
        "tns:DeliverToLenderViaFax"   => 0,
        "tns:LetterTypeValue"         => self.letter_type,
        "tns:PertainsTo"              => self.pertains_to,
        "tns:PropertyAddressLine1"    => self.property_street_address,
        "tns:PropertyAddressLine2"    => "",
        "tns:PropertyCity"            => self.property_city,
        "tns:PropertyStateCode"       => self.transaction_state,
        "tns:PropertyZipCode"         => self.property_zip,
        "tns:Sellers"                 => "",
        "tns:TransactionFundsAmount"  => "",
        "tns:LoanNumber"              => "",
        "tns:CoverBorrower"           => 0,
        "tns:CoverBuyer"              => 0,
        "tns:CoverLender"             => 1,
        "tns:CoverSeller"             => 0
      }
    }
    response = client_old_republic.call(:update_cpl) do
      message message
    end
    response.body[:update_cpl_response][:update_cpl_result]
  end

  def submit_cpl_order
    message = {
      "tns:agentNumber"          => self.agent_number,
      "tns:authorizationCode"    => self.authorization_code,
      "tns:closingMarketOrderID" => self.id,
      "tns:originatorOrderID"    => self.DisplayFileID,
      "tns:orderData"            => {
        "tns:AgentContactName"                               => self.closer_name,
        "tns:AgentContactPhone"                              => self.closer_phone,
        "tns:AgentContactFax"                                => self.closer_fax,
        "tns:DeliverToAgentViaFax"                           => 0,
        "tns:AgentContactEmail"                              => self.closer_email,
        "tns:DeliverToAgentViaEmail"                         => 0,
        "tns:Borrowers"                                      => { "tns:arr" => self.borrower_array },
        "tns:Buyers"                                         => { "tns:arr" => [] },
        "tns:BranchOfficeID"                                 => "",
        "tns:IncludeBranchOfficeOnThisLetter"                => 0,
        "tns:IncludeAllOfTheAgencyBranchOfficesOnThisLetter" => 0,
        "tns:ClosingAttorneyID"                              => "",
        "tns:ClosingAttorneyFaxNumber"                       => "",
        "tns:DeliverToClosingAttorneyViaFax"                 => 0,
        "tns:Lender"                                         => {
          "tns:Name"            => self.lender_name,
          "tns:NameContinued"   => "",
          "tns:ContactName"     => self.lender_contact_name,
          "tns:AddressLine1"    => self.lender_address_line_1,
          "tns:AddressLine2"    => self.lender_address_line_2,
          "tns:City"            => self.lender_city,
          "tns:State"           => self.lender_state,
          "tns:ZipCode"         => self.lender_zip_code,
          "tns:TelephoneNumber" => self.lender_telephone_number,
          "tns:FaxNumber"       => self.lender_fax_number,
          "tns:EmailAddress"    => self.lender_email_address
        },
        "tns:DeliverToLenderViaEmail" => 0,
        "tns:DeliverToLenderViaFax"   => 0,
        "tns:LetterTypeValue"         => self.letter_type,
        "tns:PertainsTo"              => self.pertains_to,
        "tns:PropertyAddressLine1"    => self.property_street_address,
        "tns:PropertyAddressLine2"    => "",
        "tns:PropertyCity"            => self.property_city,
        "tns:PropertyStateCode"       => self.transaction_state,
        "tns:PropertyZipCode"         => self.property_zip,
        "tns:Sellers"                 => "",
        "tns:TransactionFundsAmount"  => "",
        "tns:LoanNumber"              => "",
        "tns:CoverBorrower"           => 0,
        "tns:CoverBuyer"              => 0,
        "tns:CoverLender"             => 1,
        "tns:CoverSeller"             => 0
      }
    }
    response = client_old_republic.call(:submit_cpl_order) do
      message message
    end
    response.body[:submit_cpl_order_response][:submit_cpl_order_result]
  end

  def parse_order_response(response,user)
    if response[:result_code] == "Success"
      self.letter_reference_number = response[:provider_order_reference_number]
      self.can_resubmit_current    = true.to_s
      self.cpl_sent_by             = user
      self.cpl_updated_at          = Time.now
      self.cpl_status              = "Active"
      self.save
    end
  end

  def parse_update_response(response,user)
    if response[:result_code] == "Success"
      self.cpl_sent_by    = user
      self.cpl_updated_at = Time.now
    end
    self.cpl_status              = response[:current_reference_number_status]
    self.letter_reference_number = response[:current_reference_number]
    self.can_resubmit_current    = response[:can_resubmit_with_current_reference_number].to_s
    self.save
  end

  def parse_close_response(response,user)
    if response[:result_code] == "Success"
      self.cpl_sent_by    = user
      self.cpl_updated_at = Time.now
    end
    self.cpl_status              = response[:current_reference_number_status]
    self.letter_reference_number = response[:current_reference_number]
    self.can_resubmit_current    = response[:can_resubmit_with_current_reference_number].to_s
    self.save
  end

  def parse_cancel_response(response,user)
    if response[:result_code] == "Success"
      self.cpl_sent_by    = user
      self.cpl_updated_at = Time.now
    end
    self.cpl_status              = response[:current_reference_number_status]
    self.letter_reference_number = response[:current_reference_number]
    self.can_resubmit_current    = response[:can_resubmit_with_current_reference_number].to_s
    self.save
  end

  def parse_lookup_response(response,user)
    if response[:result_code] == "Success"
      # what to do
    end
  end

  def parse_find_response(response,user)
    if response[:result_code] == "Success"
      # what to do
    end
  end

  def fatco_rate_request
    message = {
      "agentnet:AgentNetServiceType" => "RATESFEES",
      "agentnet:IsSimultaniousPrice" => "false",
      "agentnet:ProductID" => "113",
      "agentnet:ProductName" => "Jacket",
      "agentnet:ProductType" => "ALTA Loan Policy (6-17-06)",
      "agentnet:AgentNetProductServiceId" => "737665575",
      "agentnet:RateType" => "1",
      "agentnet:LibilityAmount" => "1234560.00",
      "agentnet:EffectiveDate" => "2013-03-23T00:00:00",
      "agentnet:IsExtendedCoverage" => "false",
      "agentnet:AgentNetProductServiceId" => "737665575"
    }
    response = client_first_american.call(:rates_fees) do
      message message
    end
  end

  def fatco_validation
    response = client_first_american.call(:validate_login) do
      message message
    end
  end

  def fatco_submit_cpl_order
    message = {
      "agentnet:ActionType" => "GET_DATA",
      "agentnet:ClientRequestId" => 1827771998,
      "agentnet:FileNumber" => "",
      "agentnet:AccountNumber" => "",
      "agentnet:SystemName" => "ThirdPartySimulator",
      "agentnet:LoginAccountIdentifier" => "tdemo_1",
      "agentnet:LoginAccountPasswordText" => "abc123"
    }
    response = client_first_american.call(:submit_cpl_order) do
      message message
    end
    response.body[:submit_cpl_order_response][:submit_cpl_order_result]
  end

end