class UsersController < Devise::SessionsController
  respond_to :js, :html, :json

  def index
    @users = User.all

    respond_to do |format|
      format.html
      format.json { render :json => @users }
    end
  end

  def show
    @user = User.find(params[:id])

    respond_to do |format|
      format.html
      format.json { render :json => @user }
    end
  end

  def new
    @user = User.new

    respond_to do |format|
      format.html
      format.json { render :json => @user }
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def create
    @user = User.new

    if params[:employee] != ""
      @employee         = Employee.find params[:employee]
      @user.employee_id = @employee.ID
      @user.password    = ms_access_password(@employee.MyPassword)
      @user.email       = @employee.Email

      name             = @employee.FullName
      name             = name.split(" ")
      @user.first_name = name[0]

      if name.count > 2
        @user.last_name = name[2]
      else
        @user.last_name = name[1]
      end

      @user.created_at = Time.now.to_s(:db)
      @user.updated_at = Time.now.to_s(:db)
    end
    @user.save
    render "admin/user_list"
  end

  def update
    @user = User.find(params[:id])

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to @user, :notice => 'User was successfully updated.' }
        format.json { head :ok }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url }
      format.js   { render "/admin/user_list" }
      format.json { head :ok }
    end
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

  def set_preference
    site_preference_option = SitePreferenceOption.find(params[:site_preference_id])
    user = User.find(params[:id])
    UserPreference.destroy_all(user_id: user.id, site_preference_id: site_preference_option.site_preference_id)
    pref = user.user_preferences.create(site_preference_option: site_preference_option, site_preference: site_preference_option.site_preference)
    pref.save
    render :nothing => true
  end

  def edit_role
    user = User.find params[:id]
    case params[:do]
    when "add"
      user.add_role params[:role]
    when "remove"
      user.remove_role params[:role]
    end
    render nothing: true
  end

  def populate_permissions
    if params[:company_id] == ""
      companies = Company.find(:all, conditions: ["CompanyID IN (101,103,102,104,106,117)"])
    else
      companies = Company.where("CompanyID = #{params[:company_id]}")
    end

    User.find(:all).each do |user|
      next if user.employee == nil || user.employee.send(params[:field].to_sym) == 0
      companies.each do |company|
        user.add_permission(params[:permission], company.CompanyID) if user.belongs_to_company?(company.CompanyID) && !user.has_permission?(params[:permission], company: company.CompanyID)
      end
    end

    render js: "$('#overlay_populate_permissions').hide(); $('#overlay_populate_permissions .spinner').hide();"
  end

  private

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
