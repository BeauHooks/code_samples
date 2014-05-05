class FileDocField < ActiveRecord::Base

  after_save :update_related_fields

  belongs_to :index, foreign_key: "file_id",  primary_key: "FileID"
  belongs_to :doc,   foreign_key: "doc_id",   primary_key: "id"

  def normalize_tag(tag)
    tag.gsub!("*", "")
    tag.downcase
  end

  def update_related_fields
    if ["PROPERTY_ADDRESS", "PROPERTY_CITY", "PROPERTY_STATE"].include?(self.tag)
      file = Index.where("FileID = #{self.file_id}").first
      field = file.file_doc_fields.where("tag = 'FULL_PROPERTY_ADDRESS' and doc_id = 0 ").first
      if field == nil
        return
        field = FileDocField.new
        field.tag = "FULL_PROPERTY_ADDRESS"
        field.doc_id = 0
        field.file_id = file.FileID
        field.is_active = 1
        field.created_at = Time.now.to_s(:db)
        field.updated_at = Time.now.to_s(:db)
      end
      address_fields = file.file_doc_fields.where("tag IN ('PROPERTY_ADDRESS', 'PROPERTY_CITY', 'PROPERTY_STATE') and doc_id = 0 ").order('tag ASC')
      field.value = "#{address_fields[0].value if address_fields[0] != nil}#{", #{address_fields[1].value}" if address_fields[1] != nil && address_fields[1].value != ''}#{", #{address_fields[2].value}" if address_fields[2] != nil && address_fields[2].value != ''}"
      field.save
    end
  end

  def self.get_written_date(date)
    d = date.to_s.split(" ")
    d = d[0].split("-")

    day_number = d[2].to_s
    if day_number[0] == "0"
      day_number = day_number[-1]
    end

    if day_number[-1] == "1"
      day = "#{day_number}st"
    elsif day_number[-1] == "2"
      day = "#{day_number}nd"
    elsif day_number[-1] == "3"
      day = "#{day_number}rd"
    else
      day = "#{day_number}th"
    end

    month_list = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    month = month_list[d[1].to_i - 1]
    year = d[0].to_s

    # return "#{day} day of #{month}, #{year}"
    return "____ day of #{month}, #{year}"
  end

  def self.get_csz(tag, doc)
    file = doc.index
    csz = ""
    entity = tag.split("_")[0]
    city = doc.file_doc_fields.where("tag = '#{entity}_CITY' AND is_active != 0").first
    city = file.file_doc_fields.where("tag = '#{entity}_CITY' AND doc_id = 0 AND is_active != 0").first if city.blank?
    city = city.value unless city.blank?

    state = doc.file_doc_fields.where("tag = '#{entity}_STATE' AND is_active != 0").first
    state = file.file_doc_fields.where("tag = '#{entity}_STATE' AND doc_id = 0 AND is_active != 0").first if state.blank?
    state = state.value unless state.blank?

    zip = doc.file_doc_fields.where("tag = '#{entity}_ZIP' AND is_active != 0").first
    zip = file.file_doc_fields.where("tag = '#{entity}_ZIP' AND doc_id = 0 AND is_active != 0").first if zip.blank?
    zip = zip.value unless zip.blank?

    csz += city unless city.blank?
    csz += state.blank? ? "" : csz.blank? ? state : ", #{state}"
    csz += zip.blank? ? "" : csz.blank? ? zip : " #{zip}"

    return csz
  end

  def self.get_value(file_id, user, tag, company = 0)
    field =  FileDocField.where("tag = '#{tag}' AND doc_id = 0 AND is_active = 1").last
    file = Index.where("FileID = #{file_id}").first

    standard = []
    DocStandardField.all.each do |i|
      standard << i.tag
    end

    standard.delete("GRANTOR_NOTARY_VESTING")
    standard.delete("GRANTEE_NOTARY_VESTING")

    if standard.include?(tag)
      if field == nil
        field = FileDocField.new
        field.file_id = file.FileID
        field.doc_id = 0
        field.is_active = 1
        field.tag = tag
        field.created_by = user
        field.updated_by = user
      end

      if field.value.to_s == "" || field.value == nil
        case tag
        when "CLOSER_NAME"
          field.value = file.closer.FullName rescue ""
        when "COMPANY_TAX_ID"
          field.value = file.company.TaxID
        when "COMPANY_NAME"
          field.value = file.company.CompanyName
        when "COMPANY_ADDRESS"
          file.closer ? field.value = "#{file.closer.office.OfficeAddress1} #{file.closer.office.OfficeAddress2}" : field.value = "#{file.company.CompanyAddr}"
        when "COMPANY_CITY"
          file.closer ? field.value = file.closer.office.OfficeCity : field.value = "#{file.company.CompanyCity}"
        when "COMPANY_STATE"
          file.closer ? field.value = file.closer.office.OfficeState : field.value = "#{file.company.CompanyStateAbrv}"
        when "COMPANY_ZIP"
          file.closer ? field.value = file.closer.office.OfficeZip : field.value = "#{file.company.CompanyZip}"
        when "COMPANY_COUNTY"
          file.closer ? field.value = file.closer.office.county.CountyName : field.value = "#{file.company.default_county.CountyName}"
        when "RECORDING_DATE"
          field.value = file.COEDate.strftime("%m/%d/%Y") if file.COEDate != nil
        when "MAIL_TO"
          mail_to = FileEntity.where("FileID = #{file.FileID} AND  (Position = 1 OR Position = 7)").first
          field.value = mail_to.entity.full_name rescue ""
        when "MAIL_TO_ADDRESS"
          mail_to = FileEntity.where("FileID = #{file.FileID} AND  (Position = 1 OR Position = 7)").first
          contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' ").last rescue nil
          if contact != nil
            field.value = contact.Address
            if contact.Address2 != nil && contact.Address2 != ""
              field.value += " #{contact.Address2}"
            end
          end
        when "MAIL_TO_CITY"
          mail_to = FileEntity.where("FileID = #{file.FileID} AND  (Position = 1 OR Position = 7)").first
          contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' ").last rescue nil
          if contact != nil
            field.value = contact.City
          end
        when "MAIL_TO_STATE"
          mail_to = FileEntity.where("FileID = #{file.FileID} AND  (Position = 1 OR Position = 7)").first
          contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' ").last rescue nil
          if contact != nil
            field.value = contact.State
          end
        when "MAIL_TO_ZIP"
          mail_to = FileEntity.where("FileID = #{file.FileID} AND  (Position = 1 OR Position = 7)").first
          contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' ").last rescue nil
          if contact != nil
            field.value = contact.Zip
          end
        when "GRANTOR_NOTARY_STATE"
          field.value = Company.find(company).CompanyState rescue nil
        when "GRANTOR_NOTARY_COUNTY"
          field.value = Company.find(company).default_county.CountyName rescue nil
        when "GRANTOR_NOTARY_DATE"
          field.value = self.get_written_date(file.COEDate) if file.COEDate != nil
        when "GRANTOR_COUNTY"
          grantor = FileEntity.where("FileID = #{file.FileID} AND Position = 2").first
          contact = grantor.entity.entity_contacts.where("ContactType = 'ADDRESS' ").last rescue nil
          if contact != nil
            field.value = contact.County
          end
        when "GRANTOR_SIGNING_DATE"
          field.value = file.COEDate.strftime("%m/%d/%Y") if file.COEDate != nil
        when "GRANTEE_NOTARY_STATE"
          field.value = Company.find(company).CompanyState rescue nil
        when "GRANTEE_NOTARY_COUNTY"
          field.value = Company.find(company).default_county.CountyName rescue nil
        when "GRANTEE_NOTARY_DATE"
          field.value = self.get_written_date(file.COEDate) if file.COEDate != nil
        when "GRANTEE_COUNTY"
          grantee = FileEntity.where("FileID = #{file.FileID} AND  (Position = 1 OR Position = 7)").first
          contacts = grantee.entity.entity_contacts.where("ContactType = 'ADDRESS' ").last rescue nil
          if contact != nil
            field.value = contact.County
          end
        when "GRANTEE_SIGNING_DATE"
          field.value = file.COEDate.strftime("%m/%d/%Y") if file.COEDate != nil
        when "COMMITMENT_DATE"
          value = file.property_reports.last
          field.value = value.EffectiveDate if value != nil
        when "PROPERTY_LEGAL_DESCRIPTION"
          property_report = file.property_reports.last
          field.value = property_report.TextLegal if property_report != nil
        when "PROPERTY_TYPE"
          property_report = file.property_reports.last
          field.value = property_report.LandType if property_report != nil
        when "PROPERTY_ADDRESS"
          property_report = file.property_reports.last
          field.value = property_report.LandAddress if property_report != nil
        when "PROPERTY_CITY"
          property_report = file.property_reports.last
          field.value = property_report.LandCity if property_report != nil
        when "PROPERTY_STATE"
          property_report = file.property_reports.last
          field.value = property_report.LandState if property_report != nil
        when "PROPERTY_ZIP"
          property_report = file.property_reports.last
          field.value = property_report.LandZipCode if property_report != nil
        when "PROPERTY_COUNTY"
          property_report = file.property_reports.last
          field.value = property_report.LandCounty if property_report != nil
        when "PROPERTY_TAX_ID"
          property_report = file.TaxID1
          field.value = property_report if property_report != nil
        when "FULL_PROPERTY_ADDRESS"
          address_fields = file.file_doc_fields.where("tag IN ('PROPERTY_ADDRESS', 'PROPERTY_CITY', 'PROPERTY_STATE') and doc_id = 0 ").order('tag ASC')
          field.value = "#{address_fields[0].value if address_fields[0] != nil}#{", #{address_fields[1].value}" if address_fields[1] != nil && address_fields[1].value != ''}#{", #{address_fields[2].value}" if address_fields[2] != nil && address_fields[2].value != ''}"
        when "FILE_ID_NUMBER"
          field.value = file.DisplayFileID
        when "LENDER_NAME"
          lender = file.file_entities.where("Position = 3").last
          if lender != nil
            field.value = lender.entity.name
          end
        when "LENDER_ADDRESS_1"
          lender = file.file_entities.where("Position = 3").last
          if lender != nil
            field.value = lender.entity.address_with_2[0]
          end
        when "LENDER_ADDRESS_2"
          lender = file.file_entities.where("Position = 3").last
          if lender != nil
            field.value = lender.entity.address_with_2[1]
          end
        when "LENDER_CITY"
          lender = file.file_entities.where("Position = 3").last
          if lender != nil
            field.value = lender.entity.address_with_2[2]
          end
        when "LENDER_STATE"
          lender = file.file_entities.where("Position = 3").last
          if lender != nil
            field.value = lender.entity.address_with_2[3]
          end
        when "LENDER_ZIP"
          lender = file.file_entities.where("Position = 3").last
          if lender != nil
            field.value = lender.entity.address_with_2[4]
          end
        when "SETTLEMENT_DATE"
          field.value = file.COEDate.strftime("%m/%d/%Y") if file.COEDate != nil
        when "CLOSING_DATE"
          field.value = file.COEDate.strftime("%m/%d/%Y") if file.COEDate != nil
        else
          #do nothing
        end
        field.save
      end
    end

    value = field.value rescue ""

    if (tag == "GRANTEE_COUNTY" || tag == "GRANTOR_COUNTY") && value.to_i >= 1
      return County.where(:CountyID => value.to_i).first.CountyName rescue value
    elsif tag == "PROPERTY_LEGAL_DESCRIPTION"
      property = file.property_reports.last rescue nil
      if property != nil
        field.value = property.TextLegal
        field.updated_by = property.ModifiedBy rescue current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
        return field.value rescue ""
      end
    elsif tag == "COMMITMENT_DATE" && field != nil
        file = Index.where("FileID = #{field.file_id}").first
        property_report = file.property_reports.last
        if property_report != nil
          date = property_report.EffectiveDate.split(" ")
          field.value = date[0..-4].join(" ").titleize
          field.updated_by = property_report.ModifiedBy rescue current_user.employee_id
          field.updated_at = Time.now.to_s(:db)
          field.save
          return field.value rescue ""
        end
    elsif tag == "COMMITMENT_NUMBER" && field != nil
        file = Index.where("FileID = #{field.file_id}").first
        property_report = file.property_reports.last
        if property_report != nil
          field.value = "#{property_report.DisplayFileID}#{ " #{property_report.Amended}" if property_report.Amended != nil && property_report.Amended != "" }"
          field.updated_by = property_report.ModifiedBy rescue current_user.employee_id
          field.updated_at = Time.now.to_s(:db)
          field.save
          return field.value rescue ""
        end
    end
    value
  end
end
