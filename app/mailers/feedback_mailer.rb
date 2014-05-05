class FeedbackMailer < ActionMailer::Base
  default from: "FTWeb Feedback <ftwebfeedback@efusionpro.com>", 
          file_settings: Rails.root.join('tmp', 'confirmation_html')

  def bug_report_email(user,description)
    @user = user
    @description = description
    mail(to: "FTWeb Feedback <ftwebfeedback@efusionpro.com>", subject: "Bug Report", reply_to: @user.email)
  end

  def feature_request_email(user,description)
    @user = user
    @description = description
    mail(to: "FTWeb Feedback <ftwebfeedback@efusionpro.com>", subject: "Feature Request", reply_to: @user.email)
  end

  def file_confirmation_fail_email(user,exceptions)
    @user = user
    @exceptions = exceptions
    if Rails.env.production?
      mail(to: "FTWeb Feedback <ftwebfeedback@efusionpro.com>", subject: "File Confirmation Send Failure", reply_to: "ftwebfeedback@efusionpro.com")
    else
      mail(to: "#{@user.first_name} #{@user.last_name} <#{@user.email}>", subject: "File Confirmation Send Failure", reply_to: "ftwebfeedback@efusionpro.com")
    end
  end

  def file_confirmation_email(user, file_number, name, email, hide_notes = false, delivery_method = "default")
    @user = user
    @file = Index.where("FileID = #{file_number}").first
    @company = Company.find @file.Company
    @notes = @file.file_notes.where("IsPrivate = 0") if !hide_notes
    @delivery_method = delivery_method
    
    case @file.Company.to_i
    when 101
      @logo = "sutc_logo_color.jpg"
    when 102
      @logo = "terra_logo_color.jpg"
    else
      @logo = ""
    end

    attachments.inline["logo.jpg"] = File.read( Rails.root.join("app/assets/images/#{@logo}") ) if @logo != ""

    @county_properties = []
    @county_images = []
    
    @file.file_properties.where("Inactive = 0").each do |p| 
      unless p.TaxID == nil
        property = Taxroll1.where("serialnum = '#{p.TaxID.gsub("'", "\\\\'").upcase}'").first
        if property != nil
          @county_properties << property

          image = TaxrollImages.where("AccountNum = '#{property.accountnum}'").first
          if image != nil && Rails.env != "staging"
            path = DriveMap.posix(image.BaseDir + image.FileName)
            attachments.inline[image.FileName] = File.read(path)
            @delivery_method == "default" ? @county_images << image.FileName : @county_images << path
          else
            @county_images << nil
          end
        end
      end 
    end
    
    Rails.env.production? ? @testing = false :  @testing = true
    mail(to: "#{name.gsub(/[^A-Za-z0-9\s]/, "")} <#{email}>", subject: "New File #{@company.DirName} ##{@file.DisplayFileID}", from: "#{@user.employee.FullName} <#{@user.email}>")  
  end

  def file_confirmation_email_company(user, file_number, name, email)
    @user = user
    @file = Index.where("FileID = #{file_number}").first
    @company = Company.find @file.Company
    @notes = @file.file_notes.where("IsPrivate = 0")
    
    case @file.Company.to_i
    when 101
      attachments.inline["logo.jpg"] = File.read( Rails.root.join("app/assets/images/sutc_logo_color.jpg") )
    when 102
      attachments.inline["logo.jpg"] = File.read( Rails.root.join("app/assets/images/terra_logo_color.jpg") )
    end
    @county_properties = []
    @county_images = []
    
    @file.file_properties.where("Inactive = 0").each do |p| 
      unless p.TaxID == nil
        property = Taxroll1.where("serialnum = '#{p.TaxID.gsub("'", "\\\\'").upcase}'").first
        if property != nil
          @county_properties << property

          image = TaxrollImages.where("AccountNum = '#{property.accountnum}'").first
          if image != nil && Rails.env == "production"
            path = DriveMap.posix(image.BaseDir + image.FileName)
            attachments.inline[image.FileName] = File.read(path)
            @county_images << image.FileName
          else
            @county_images << nil
          end
        end
      end 
    end
    
    Rails.env.production? ? @testing = false :  @testing = true
    mail(to: "#{name.gsub(/[^A-Za-z0-9\s]/, "")} <#{email}>", subject: "#{"CONFIDENTIAL: " if @file.confidential?}New File #{@company.DirName} ##{@file.DisplayFileID}", reply_to: "No Reply <no-reply@efusionpro.com>")
  end
end
