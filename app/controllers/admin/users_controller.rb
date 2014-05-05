class Admin::UsersController < AdminController
  respond_to :js, :html, :json

  before_filter :set_options

  def index
    @search_results = User.all
    @user = @search_results.first
  end

  def result_detail
    unless params[:id] == "0"
      @user = User.find(params[:id])
    end
  end

  def display_search_results
    unless params[:type].blank? || params[:search].blank?
      @search_results = User.where("#{params[:type]} LIKE '#{params[:search].gsub(/\*/, "%")}'")
    else
      @search_results = []
    end
  end

  def create
    user = User.new

    if params[:employee] != ""
      employee         = Employee.find params[:employee]
      user.employee_id = employee.ID
      user.password    = ms_access_password(employee.MyPassword)
      user.email       = employee.Email

      name             = employee.FullName
      name             = name.split(" ")
      user.first_name = name[0]

      if name.count > 2
        user.last_name = name[2]
      else
        user.last_name = name[1]
      end

      user.created_at = Time.now.to_s(:db)
      user.updated_at = Time.now.to_s(:db)
    end
    user.save

    @search_results = [user]

    respond_to do |format|
      format.js {render "admin/create_user"}
    end
  end

  def update
    @user = User.find(params[:id])
    @user.update_attributes(params[:user])
    render nothing: true
  end

  def edit_permission
    user = User.find params[:id]
    params[:company] == "" ? company = nil : company = params[:company]
    case params[:do]
    when "add"
      user.add_permission params[:permission], company: company
    when "remove"
      user.remove_permission params[:permission], company: company
    end
    render nothing: true
  end

  def edit_company
    user = User.find params[:id]
    case params[:do]
    when "add"
      user.add_company params[:company_id]
      render nothing: true
    when "remove"
      if user.companies.size > 1
        user.remove_company params[:company_id]
        render nothing: true
      else
        @company = Company.find params[:company_id]
      end
    end
  end

  def set_user_preference
    site_preference_option = SitePreferenceOption.find(params[:site_preference_id])
    user = User.find(params[:id])
    UserPreference.destroy_all(objects_id: user.id, objects_type: "User", name: site_preference_option.site_preference.name)
    UserPreference.create({objects_id: user.id, objects_type: "User", name: site_preference_option.site_preference.name, value: site_preference_option.setting})
    render :nothing => true
  end

  def destroy
    user_id = params[:id]
    User.find(params[:id]).destroy

    render js: "
      $('#user_results tr##{user_id}').remove();
      if($('#user_results').find('.active_row').length == 0){
        if($('#user_results').find('.result_row').length > 0){
          $(\"#user_detail\").html(\"<p class='no_result'>Loading User...</p>\");
          $('#user_results tr:first').click();
        }
        else{
          $(\"#user_detail\").html(\"<p class='no_result'>Nothing to display.</p>\");
        }
      }
    "
  end

  private
    def set_options
      @select_options = User::SELECT_OPTIONS
      @search_display = User::SEARCH_DISPLAY
    end

    def ms_access_password(password)
      char_codes = []
      chars      = []
      password.size.times.each do |c|
        char_codes << password[c].ord
      end

      char_codes.size.times.each do |c|
        chars << (char_codes[c] - 3).chr
      end
      return chars.join.downcase
    end
end