class RolodexAttachmentsController < ApplicationController
  def user_file_upload
    @filebin = FileBin.where("IsUserImage = -1").order("DirName ASC")
    @entity  = Entity.find params[:entity_id]
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
        render js: "$('div#error').html('Type must be selected!'); $('div#error').show(); $('div#error').delay(2000).fadeOut(3000);"
      else
        @user_file            = EntityImage.new
        file                  = params[:file]
        ext                   = File.extname(file)
        filebin               = FileBin.where("Description = '#{params[:image_type]}'").first
        tempfile              = random_string + "_user"
        @user_file.EntityID   = params[:entity_id]
        @user_file.ContactID  = 0
        @user_file.ImageType  = params[:image_type]
        @user_file.ScanDate   = Time.now.to_s(:db)
        @user_file.IsPrivate  = 0
        @user_file.ImageNotes = params[:image_notes]
        @user_file.tempfile   = tempfile
        full_file_path        = "F:\\images\\userimages\\#{filebin[:DirName]}\\#{entity_id_prefix(params[:entity_id])}\\#{params[:entity_id]}#{ext}".downcase
        @user_file.FileName   = full_file_path
        @user_file.save

        #
        # Upload file and put it in a temp location (Must be last)
        #
        if params[:keep_file]
          temp_path    = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{file}"
          process_path = Rails.root.join "tmp/process_images/#{tempfile}"
          FileUtils.cp(temp_path, process_path)
        else
          temp_path    = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{file}"
          process_path = Rails.root.join "tmp/process_images/#{tempfile}"
          FileUtils.mv(temp_path, process_path)
        end

        @success = true
        respond_to do |format|
          format.js { render "rolodex_attachments/process.js" }
        end
      end
    else
      @attachment = EntityImage.new
      respond_to do |format|
        format.js { render "rolodex_attachments/process.js" }
      end
    end
  end

  def load_process_images
    @entity  = Entity.find params[:entity_id]
    @filebin = FileBin.where("IsUserImage = -1").order("DirName ASC")
    respond_to do |format|
      format.js { render "rolodex_attachments/process.js" }
    end
  end

  def request_file
    file      = params[:file]
    temp_path = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{file}"
    send_file temp_path
  end

  def dnd_upload
    @entity         = Entity.find(params[:entity_id])
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
      user_id_folder = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}"
      user_id_folder.realpath
    rescue Errno::ENOENT
      user_id_folder.mkdir
    end
    #
    # Check to see if there is a folder already created with the Entity ID, create it if there isn't.
    #
    begin
      entity_id_folder = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}"
      entity_id_folder.realpath
    rescue Errno::ENOENT
      entity_id_folder.mkdir
    end
    #
    # Check to see if there is a file with the same name, if there is then loop till there isn't, e.g. "image(1).pdf"
    #
    if params[:totalchunks].to_i == 1
      @temp_path = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{tempfile}.#{ext}"
    else
      @temp_path = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{tempfile}"
    end
    if @temp_path.exist?
      until @temp_path.exist? == false
        count += 1
        @temp_path = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{tempfile}(#{count}).#{ext}"
      end
    end

    File.open(@temp_path, "wb") { |f| f.write(`cat #{params[:file].tempfile.path}`) }
    if params[:totalchunks].to_i > 1
      parts = []
      files = Dir.entries(Rails.root.join("tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/"))
      files.each do |file|
        parts << file if file.include?("#{original_filename}.") && file.include?(".part")
      end
      @percent = (parts.size/params[:totalchunks].to_f*100).to_i.to_s
      if parts.size == params[:totalchunks].to_i
        count = 0
        file_path = Rails.root.join("tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{original_filename}.#{ext}")
        if file_path.exist?
          until file_path.exist? == false
            count += 1
            file_path = Rails.root.join("tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{original_filename}(#{count}).#{ext}")
          end
        end
        open(file_path, "a") do |f|
          parts.sort_by!{|p| p.split(".")[1].to_i}
          parts.each do |p|
            f << File.read(Rails.root.join("tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{p}"))
            FileUtils.rm(Rails.root.join("tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{p}"))
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

  def reload_entity_images
    @entity  = Entity.find params[:entity_id]
    @images = @entity.entity_images.where("IsPrivate" => 0).order("ScanDate DESC")
    respond_to do |format|
      format.js { render "rolodex/reload_entity_images" }
    end
  end

  def user_image
    @image_id = params[:image_id]
    send_file DriveMap.posix EntityImage.find(@image_id).FileName
  end

  def remove_temp
    @filebin  = FileBin.where("IsUserImage = -1").order("DirName ASC")
    @entity   = Entity.find params[:entity_id]
    temp_file = Rails.root.join "tmp/rolodex_dnd/#{current_user.employee_id}/#{@entity.EntityID}/#{params[:file]}"
    File.delete(temp_file)
    respond_to do |format|
      format.js { render "rolodex_attachments/process.js" }
    end
  end
end
