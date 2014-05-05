class ApplicationController < ActionController::Base
  include ApplicationHelper
  layout :specify_layout
  protect_from_forgery
  before_filter :authenticate_user!, :check_company, :preload_permissions, :page_name
  after_filter :flash_to_headers

  public

  def flash_to_headers
    return unless request.xhr?
    response.headers['X-Message'] = flash_message
    response.headers['X-Message-Type'] = flash_type.to_s

    flash.discard # Don't want the flash to appear when you reload the page
  end

  def add_task
    @title      = params[:title]
    @identifier = params[:identifier].gsub(".","_").gsub("&","_").gsub(" ","_").gsub("#","").gsub("'","")

    render "layouts/js/task"
  end

  def current_file
	  Index.find(session[:file_indices_id])
  rescue ActiveRecord::RecordNotFound
    file = Index.create
	  session[:file_indices_id] = file.id
	  file
  end

  def large_text
    if params[:editable] == "false"
      @editable = "readonly='readonly'"
    else
      @editable = ""
    end

    if params[:title] != nil && params[:title] != ""
      @title = params[:title]
    else
      @title = "Long Text"
    end

    if params[:text] != nil
      @text = params[:text]
    end

    if params[:post] != nil && params[:post] != ""
      @post = "$.post('#{params[:post]}');"
    elsif params[:field] != nil && params[:field] != ""
      @post = "$('##{params[:field]}').val($('#large_text_area').val()).change();"
    else
      @post = nil
    end

    if params[:confirm] != nil && params[:confirm] != ""
      @confirm = params[:confirm]

      case @confirm
      when "Yes"
        @close = "No"
      when "Confirm"
        @close = "Deny"
      when "Save"
        @close = "Close"
      when "Update"
        @close = "Not Right Now"
      else
        @close = "Cancel"
      end
    else
      @confirm = nil
    end

    respond_to do |format|
      format.js { render 'layouts/large_text' }
    end
  end

  def flash_notice
    params[:type] == nil ? @type = "alert" : @type = params[:type]

    params[:notice] != nil && params[:notice] != "" ? @notice = params[:notice] : @notice = "Are you sure?"

    params[:title] != nil && params[:title] != "" ? @title = params[:title] : @title = "Alert"

    params[:post] != nil && params[:post] != "" ? @post = "addToQueue('notice_post', '#{params[:post]}', '#{params[:request_type] || "GET"}');" : @post = ""
    @post += " #{params[:click_action]}" if params[:click_action] != nil && params[:click_action] != ""

    params[:cancel_action] != nil && params[:cancel_action] != "" ? @cancel_action = params[:cancel_action] : @cancel_action = ""

    @type_action_text = params[:type_action] if params.has_key?(:type_action)

    if params[:confirm] != nil && params[:confirm] != ""
      @confirm = params[:confirm]

      case @confirm
      when "Yes"
        @close = "No"
      when "Confirm"
        @close = "Deny"
      when "Save"
        @close = "Close"
      when "Update"
        @close = "Not Right Now"
      else
        @close = "Cancel"
      end
    else
      @confirm = "Okay"
      @cancel_action != "" ? @close = "Cancel" : @close = ""
    end

    params[:list] != nil && params[:list] != "" ? @list = params[:list] : @list = []

    respond_to do |format|
      format.js { render 'layouts/flash_notice' }
    end
  end

  def usps
    url = build_usps_url(params[:tax_id], params[:address1], params[:address2], params[:city], params[:state], params[:zip])
    render js: "window.open('#{url}');"
  end

  private

  def flash_message
    [:error, :warning, :notice].each do |type|
      return flash[type] unless flash[type].blank?
    end
  end

  def flash_type
    [:error, :warning, :notice].each do |type|
      return type unless flash[type].blank?
    end
  end

  def preload_permissions
    if user_signed_in?
      user = current_user
      Permission.find(:all).each do |p|
        if p.category == "application"
          instance_variable_set("@permission_#{p.name}", user.has_permission?(p.name))
        else
          instance_variable_set("@permission_#{p.name}", user.has_permission?(p.name, company: session[:company]))
        end
      end
      session[:permissions_loaded] = true
    end
  end

  def check_company
    if !current_user.nil?
      companies = []
      current_user.companies.each do |c|
        companies << c.CompanyID
      end
      if companies.include?(session[:company].to_i) == false
        session[:company] = current_user.companies.first.CompanyID
      end
    end
  end

  def check_homepage
    request.port ? port = ":#{request.port}" : port = ""
    if request.url == "#{request.protocol}#{request.host}#{port}/login" && user_signed_in?
      page = current_user.users_preferences[:homepage]
      redirect_to "/#{page}"
    end
  end

  def after_sign_in_path_for(resource_or_scope)
    session[:company] = current_user.employee.Company
    index_index_path
  end

  def after_sign_out_path_for(resource_or_scope)
    new_user_session_path
  end

  def datetime_parse(datetime)
    # Format the date because rails and sql don't like americans
    split      = datetime.split(' ')
    split_date = split[0].split('/')
    month      = split_date[0]
    day        = split_date[1]
    year       = split_date[2]

    DateTime.parse("#{year}-#{month}-#{day} #{split[1]} #{split[2]}").strftime("%Y-%m-%d %H:%M:%S")
  end

  def file_id_prefix(file_id)
    prefix = file_id.to_i / 1000
    prefix.to_s
  end

  def entity_id_prefix(file_id)
    prefix = file_id.to_i / 1000
    prefix.to_s
  end

  def random_string(length=10)
    string   = ''
    chars    = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ123456789'
    length.times { |i| string << chars[rand(chars.length)] }
    string
  end

  def page_name
    case controller_name
    when "dashboard"
      @page_name = "Dashboard"
    when "index"
      @page_name = "File Index"
    when "rolodex"
      @page_name = "Rolodex"
    when "properties"
      @page_name = "Property Lookup"
    when "recording_entries"
      @page_name = "Recorder Lookup"
    end
  end

  protected

  def specify_layout
    devise_controller? ? "login" : "application"
  end
end
