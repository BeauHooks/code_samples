class FileImagesController < ApplicationController
  def file_image_upload
    @filebin = FileBin.where("IsFileImage = -1").order("DirName ASC")
    @file    = Index.find params[:file_id]
    #
    # When I upload a file, the application will determine where the file needs to go and create that
    # database entry for that file and put it in a temp location using a unique temp file name.  After
    # that a ruby application on the web server will watch that directory and pick up that file, read in
    # the file name and do a lookup on the file images table for that temp file name in the temp file name field.
    # After that it will read in the location to where the file is supposed to go and copy the file to that location.
    #
    # Process Form
    #

    if request.post?
      if params[:image_type] == ""
        render js: "$('#failed').show().delay(2500).fadeOut(1300); $('#no_type').show();"
      else
        @file_image               = FileImage.new
        file                      = params[:file]
        ext                       = File.extname(file)
        filebin                   = FileBin.where("Description = '#{params[:image_type]}'").first
        company                   = Company.find @file.Company
        tempfile                  = random_string + "_file"
        @file_image.FileID        = @file.FileID
        @file_image.DisplayFileID = @file.DisplayFileID
        @file_image.ImageType     = filebin[:DirName]
        @file_image.ImageDate     = Time.now.to_s(:db)
        @file_image.ImageNotes    = params[:image_notes]
        @file_image.EnteredBy     = current_user.employee_id
        @file_image.tempfile      = tempfile
        full_file_path            = "F:\\images\\#{company[:DirName]}\\#{filebin[:DirName]}\\#{file_id_prefix(@file.DisplayFileID)}\\#{@file.DisplayFileID}#{ext}".downcase
        @file_image.FullFileName  = full_file_path
        @file_image.save

        #
        # Upload file and put it in a temp location (Must be last)
        #
        file_folder = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}"
        file_list   = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/*"
        count = Dir[file_list].size

        if params[:keep_file]
          temp_path    = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{file}"
          process_path = Rails.root.join "tmp/process_images/#{tempfile}"
          FileUtils.cp(temp_path, process_path)
        else
          temp_path    = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{file}"
          process_path = Rails.root.join "tmp/process_images/#{tempfile}"
          FileUtils.mv(temp_path, process_path)
        end
        #
        # Remove the file id directory if the file count is 0
        #
        file_folder.rmdir if count - 1 == 0

        @success = true
        render "file_images/process"
      end
    else
      @file = Index.where("FileID" => params[:file_id]).first
      @attachment = FileImage.new
      respond_to do |format|
        format.js { render "file_images/process" }
      end
    end
  end

  def view_log
    @file         = Index.where("FileID = #{params[:file_id]}").first
    @file_images  = @file.file_images.where("Inactive = false").order("ImageDate DESC")
    @delivery_log = SecureDeliveryLog.get_history(@file_images.first.ImageID) rescue []
  end

  def delivery_history
    @delivery_log = SecureDeliveryLog.get_history(params[:id])
  end

  def load_process_images
    @pre_hud = params[:pre_hud]
    if params.has_key?(:display_file_id)
      @file = Index.where("FileID" => params[:display_file_id]).first
    else
      @file = Index.find params[:file_id]
    end
    @filebin = FileBin.where("IsFileImage = -1").order("DirName ASC")
    respond_to do |format|
      format.js { render "file_images/process" }
    end
  end

  def request_file
    file      = params[:file]
    temp_path = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{file}"
    send_file temp_path
  end

  def dnd_upload
    @file           = Index.where("FileID" => params[:display_file_id]).first
    @filename       = params[:filename]
    @identifier     = params[:identifier].gsub(".","_").gsub("&","_").gsub(" ","_").gsub("#","").gsub("'","")
    count           = 0
    filter_filename = params[:filename].gsub("&","_").gsub(" ","_").gsub("#","").gsub("'","").split(".")
    filter_filename.pop
    original_filename = filter_filename.join("_")
    ext               = params[:filename].split(".").last
    if params[:totalchunks].to_i == 1
      tempfile = original_filename
    else
      tempfile = "#{original_filename}.#{params[:filepart]}.part"
    end
    #
    # Check to see if there is a folder already created with the user employee ID, create it if there isn't.
    #
    begin
      user_id_folder = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}"
      user_id_folder.realpath
    rescue Errno::ENOENT
      user_id_folder.mkdir
    end
    #
    # Check for company id folder, create it if there isn't.
    #
    begin
      company_id_folder = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}"
      company_id_folder.realpath
    rescue Errno::ENOENT
      company_id_folder.mkdir
    end
    #
    # Check for file number directory, create it if there isn't.
    #
    begin
      file_id_folder = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}"
      file_id_folder.realpath
    rescue Errno::ENOENT
      file_id_folder.mkdir
    end
    #
    # Check to see if there is a file with the same name, if there is then loop till there isn't, e.g. "image(1).pdf"
    #
    if params[:totalchunks].to_i == 1
      @temp_path = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{tempfile}.#{ext}"
    else
      @temp_path = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{tempfile}"
    end
    if @temp_path.exist?
      until @temp_path.exist? == false
        count += 1
        @temp_path = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{tempfile}(#{count}).#{ext}"
      end
    end

    File.open(@temp_path, "wb") { |f| f.write(`cat #{params[:file].tempfile.path}`) }
    if params[:totalchunks].to_i > 1
      parts = []
      files = Dir.entries(Rails.root.join("tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/"))
      files.each do |file|
        parts << file if file.include?("#{original_filename}.") && file.include?(".part")
      end
      @percent = (parts.size/params[:totalchunks].to_f*100).to_i.to_s
      if parts.size == params[:totalchunks].to_i
        count = 0
        file_path = Rails.root.join("tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{original_filename}.#{ext}")
        if file_path.exist?
          until file_path.exist? == false
            count += 1
            file_path = Rails.root.join("tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{original_filename}(#{count}).#{ext}")
          end
        end
        open(file_path, "a") do |f|
          parts.sort_by!{|p| p.split(".")[1].to_i}
          parts.each do |p|
            f << File.read(Rails.root.join("tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{p}"))
            FileUtils.rm(Rails.root.join("tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{p}"))
          end
        end
      end
    else
      @percent = "100"
    end
    respond_to do |format|
      format.js {}
    end
  end

  def remove_temp
    @file = Index.find params[:file_id]
    @filebin    = FileBin.where("IsFileImage = -1").order("DirName ASC")

    file_folder = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}"
    file_list   = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/*"
    count = Dir[file_list].size

    temp_file = Rails.root.join "tmp/index_dnd/#{current_user.employee_id}/#{@file.Company}/#{@file.DisplayFileID}/#{params[:file]}"
    File.delete(temp_file)
    #
    # Remove the file id directory if the file count is 0
    #
    file_folder.rmdir if count - 1 == 0

    respond_to do |format|
      format.js { render "file_images/process.js" }
    end
  end

  def toggle_active
    @image = FileImage.find params[:id]
    @file = Index.where("FileID = #{@image.FileID}").first

    if params[:active] == "true"
      @image.Inactive = 0
    else
      @image.Inactive = -1
    end
    @image.save

    # FIXME: Need to make these visible to ADMIN user
    @images = @file.file_images.where("Inactive = 0 AND IsPrivate = 0").order("ImageDate DESC")
    @show_inactive = true
  end

  def show_inactive
    @file = Index.find(params[:index_id])
    @toggle = params[:toggle].to_bool

    if @toggle
      @images = @file.file_images.where("IsPrivate = 0").order("ImageDate DESC")
    else
      @images = @file.file_images.where("Inactive = 0 AND IsPrivate = 0").order("ImageDate DESC")
    end
  end

  def send_images
    @file        = Index.where("FileID = #{params[:file_id]}").first
    @failures    = []
    post_success = ""
    exceptions   = Hash.new
    @list        = []

    if params[:do] == "overlay"
      if params[:type] == "file_images"
        params[:list].each do |id|
          image = FileImage.find id
          container = Hash.new
          container["id"]   = image.ImageID
          container["type"] = image.ImageType
          container["note"] = image.ImageNotes rescue ""
          container["create_date"] = image.ImageDate.to_s(:std)
          container["create_user"] = image.entered_by.FullName rescue ""
          @list << container
        end
      else
      end
      @images = params[:list]
    else
      unless !params.has_key?(:entity)
        links        = ""
        message      = "Default Text"
        post_success = "addToQueue('confirmation_success', 'application/flash_notice?title=Send Image Success&notice=Success! Your file images were sent.&type=confirmation');"
        if Rails.env.production?
          # Send confirmation to customers
          params[:entity].each do |entity_id, email|
            name        = Entity.find(entity_id).name
            public_user = PublicUser.find_by_email(email)
            if public_user.nil?
              public_user          = PublicUser.new
              public_user.email    = email
              public_user.password = random_string
              public_user.save!
              public_user.reset_authentication_token!
            elsif public_user.authentication_token.nil?
              public_user.reset_authentication_token!
            end
            params[:list].each do |l|
              temp_file              = random_string(20)
              image                  = FileImage.find(l)
              image_ext              = image.FullFileName.split(".")[1]
              delivery               = SecureDelivery.new
              delivery.user_id       = public_user.id
              delivery.file_image_id = image.ImageID
              delivery.name          = image.ImageType + ".#{image_ext.downcase}"
              delivery.description   = image.ImageNotes
              delivery.temp_file     = temp_file
              delivery.expires_at    = (Time.now + 30.days).to_s(:db)
              delivery.created_by    = current_user.id
              delivery.created_at    = Time.now.to_s(:db)
              delivery.updated_at    = Time.now.to_s(:db)
              delivery.save!
              delivery_log               = SecureDeliveryLog.new
              delivery_log.user_id       = public_user.id
              delivery_log.file_image_id = image.ImageID
              delivery_log.name          = image.ImageType + ".#{image_ext.downcase}"
              delivery_log.description   = image.ImageNotes
              delivery_log.expires_at    = (Time.now + 30.days).to_s(:db)
              delivery_log.created_by    = current_user.id
              delivery_log.created_at    = Time.now.to_s(:db)
              delivery_log.save!
              links += "#{image.ImageType} - <a href='https://www.filetrakpro.com/login?auth_token=#{public_user.authentication_token}&perform=secure_delivery&get_file=#{temp_file}'>View</a><br />"
              image_location = File.expand_path(DriveMap.posix(image.FullFileName))
              secure_delivery_location = File.expand_path("/home/deploy/apps/shared/secure_downloads")
              FileUtils.cp(image_location, File.join(secure_delivery_location, temp_file))
            end
            message = "#{links}<br/>#{params[:message].gsub("\n","<br />")}"
            begin
              SecureDownloadMailer.secure_download(email, "#{current_user.employee.FullName} <#{current_user.employee.Email}>", params[:subject], message).deliver!
            rescue => ex
              @failures << "#{name}: #{email}".gsub("'", "\\\\\'")
              exceptions["#{name}: #{email}"] = [ex.message, ex.backtrace]
            end
          end
        else
          # Test in staging or development
          name  = current_user.employee.FullName
          email = current_user.employee.Email
          params[:entity].each do |entity_id, email|
            name        = Entity.find(entity_id).name
            public_user = PublicUser.find_by_email(email)
            if public_user.nil?
              public_user          = PublicUser.new
              public_user.email    = email
              public_user.password = random_string
              public_user.save!
              public_user.reset_authentication_token!
            elsif public_user.authentication_token.nil?
              public_user.reset_authentication_token!
            end
            params[:list].each do |l|
              temp_file              = random_string(20)
              image                  = FileImage.find(l)
              image_ext              = image.FullFileName.split(".")[1]
              delivery               = SecureDelivery.new
              delivery.user_id       = public_user.id
              delivery.file_image_id = image.ImageID
              delivery.name          = image.ImageType + ".#{image_ext.downcase}"
              delivery.description   = image.ImageNotes
              delivery.temp_file     = temp_file
              delivery.expires_at    = (Time.now + 30.days).to_s(:db)
              delivery.created_by    = current_user.id
              delivery.created_at    = Time.now.to_s(:db)
              delivery.updated_at    = Time.now.to_s(:db)
              delivery.save!
              delivery_log               = SecureDeliveryLog.new
              delivery_log.user_id       = public_user.id
              delivery_log.file_image_id = image.ImageID
              delivery_log.name          = image.ImageType + ".#{image_ext.downcase}"
              delivery_log.description   = image.ImageNotes
              delivery_log.expires_at    = (Time.now + 30.days).to_s(:db)
              delivery_log.created_by    = current_user.id
              delivery_log.created_at    = Time.now.to_s(:db)
              delivery_log.save!
              links += "#{image.ImageType} - <a href='http://localhost:3001/login?auth_token=#{public_user.authentication_token}&perform=secure_delivery&get_file=#{temp_file}'>View</a><br />"
              image_location = File.expand_path(DriveMap.posix(image.FullFileName))
              secure_delivery_location = File.expand_path("/home/deploy/apps/shared/secure_downloads")
              FileUtils.cp(image_location, File.join(secure_delivery_location, temp_file))
            end
            message = "#{links}<br/>#{params[:message].gsub("\n","<br />")}"
            @failures << "#{name}: #{email}"
          end

          begin
            SecureDownloadMailer.secure_download(email, "#{current_user.employee.FullName} <#{current_user.employee.Email}>", params[:subject], message).deliver!
          rescue => ex
            @failures << "#{name}: #{email}"
            exceptions["#{name}: #{email}"] = [ex.message, ex.backtrace]
          end
        end
      end

      if @failures.size > 0
        # Send failures to FTWeb Feedback
        FeedbackMailer.file_confirmation_fail_email(current_user,exceptions).deliver if Rails.env.production?
        render js: "closeOverlay('send_images'); addToQueue('send_image_failure', 'application/flash_notice?title=Send Image Failure&notice=File images could not be sent to the following:&list[]=#{@failures.join("&list[]=")}');"
      else
        render js: "closeOverlay('send_images'); #{post_success}"
      end
    end
  end

  def search_entities
    @results = Entity.search_by_type("Name", params[:search_value], false)

    respond_to do |format|
      format.js { render "file_images/display_entity_search_results" }
    end
  end

  def reload_file_images
    @file   = Index.find params[:file_id]
    @images = @file.file_images.where("IsPrivate" => 0, "Inactive" => 0).order("ImageDate DESC")
  end

  def view_all
    if current_user.employee.ACViewPrivateFile == 0
      render nothing: true
      return
    end

    file = Index.find params[:file_id]
    list = ""
    var = "nothing"

    @tmp_file = random_string + ".pdf"
    tmp_path = Rails.root.join("tmp", "#{@tmp_file}")

    file_images = file.file_images.where("FullFileName LIKE '%%.pdf'")
    if file_images.size == 0
      render nothing: true
      return
    elsif file_images.size == 1
      file_name = DriveMap.posix( file_images.first.FullFileName ).downcase
      @created = system("cp #{file_name} #{tmp_path}")
    else
      file_images.each do |image|
        image_path = DriveMap.posix( image.FullFileName ).downcase
        list += " " + image_path
      end
      @created = system("pdftk#{list} cat output #{tmp_path}")
    end
  end

  def edit
    @image = FileImage.find params[:id]
  end

  def update
    @file  = Index.find params[:file_id]
    @image = FileImage.find params[:id]

    params.each do |key, value|
      unless !@image.attributes.include?(key)
        @image.send(key + "=", (value || nil) )
      end
    end

    @image.save
  end
end