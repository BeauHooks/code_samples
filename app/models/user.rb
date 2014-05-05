class User < ActiveRecord::Base
  devise :database_authenticatable, :lockable,
         :recoverable, :rememberable, :trackable, :validatable

  after_create :new_user_defaults
  before_destroy :remove_user_related


  SELECT_OPTIONS = [
                    ["Last Name","last_name"],
                    ["First Name","first_name"]
                  ]

  SEARCH_DISPLAY = [
                    { label: 'First Name',      attribute: 'first_name',   style: 'w100', format: 'to_s',     limit: 0,  to_link: false,  :link_type => '' },
                    { label: 'Last Name',       attribute: 'last_name',    style: 'w200', format: 'to_s',     limit: 15, to_link: false,  :link_type => '' },
                    { label: 'Email',           attribute: 'email',        style: 'w100', format: 'to_s',     limit: 0,  to_link: true,   :link_type => 'email' }
                  ]

  default_scope {order("first_name")}

  # Should be in a concern at some point
  scope :with_users_preferences, -> {
    joins("JOIN users_preferences ON (users_preferences.objects_id = #{self.table_name}.#{self.primary_key} AND users_preferences.objects_type = '#{self.base_class.name}')")
    .select("DISTINCT #{self.table_name}.*")
  }

  scope :with_users_preferences_for, ->(var) {
    joins("JOIN users_preferences ON (users_preferences.objects_id = #{self.table_name}.#{self.primary_key} AND users_preferences.objects_type = '#{self.base_class.name}') AND users_preferences.var = '#{var}'")
  }

  scope :without_users_preferences, -> {
    joins("LEFT JOIN users_preferences ON (users_preferences.objects_id = #{self.table_name}.#{self.primary_key} AND users_preferences.objects_type = '#{self.base_class.name}')")
    .where("users_preferences.id IS NULL")
  }

  scope :without_users_preferences_for, ->(var) {
    where('users_preferences.id IS NULL')
    .joins("LEFT JOIN users_preferences ON (users_preferences.objects_id = #{self.table_name}.#{self.primary_key} AND users_preferences.objects_type = '#{self.base_class.name}') AND users_preferences.var = '#{var}'")
  }

  attr_accessible :employee_id, :email, :password, :password_confirmation, :first_name, :last_name, :remember_me

  has_many :user_permissions
  has_many :permissions, through: :user_permissions
  has_and_belongs_to_many :companies, order: "CompanyName ASC"
  has_one  :employee,                   foreign_key: 'ID',          primary_key: 'employee_id'
  has_many :closing_protection_letters, foreign_key: 'created_by',  primary_key: 'id'
  has_many :closing_protection_letters, foreign_key: 'updated_by',  primary_key: 'id'
  has_many :closing_protection_letters, foreign_key: 'cpl_sent_by', primary_key: 'id'

  def users_preferences
    ScopeUserPreference.for_object(self)
  end

  def new_user_defaults
    self.add_company(101)
  end

  def name
  	"#{self.first_name} #{self.last_name}"
  end

  def add_permission(permission, option={})
    perm = Permission.where(name: permission).first
    user_permission = UserPermission.new(user: self, permission: perm, company_id: option[:company])
    user_permission.save
  end

  def remove_permission(permission, option={})
    perm = Permission.where(name: permission).first
    user_permission = UserPermission.where(user_id: self.id, permission_id: perm.id, company_id: option[:company]).first
    user_permission.destroy unless user_permission.blank?
  end

  def has_permission?(name, option={})
    permission = Permission.where("name = '#{name}'").first
    if permission != nil
      if option[:company] != nil
        has_permission = self.permissions.where("users_permissions.company_id = #{option[:company].to_i} AND name = '#{name}'").size > 0
        if has_permission == false
          permission.default_permission?
        else
          has_permission
        end
      else
        has_permission = self.permissions.where("name = '#{name}'").size > 0
        if has_permission == false
          permission.default_permission?
        else
          has_permission
        end
      end
    else
      false
    end
  end

  def get_permissions
    permissions = []
    self.permissions.each { |p| permissions << p.name }
    permissions
  end

  def add_company(company_id)
    company = Company.find company_id
    self.companies << company
  end

  def remove_company(company_id)
    company = Company.find company_id
    self.companies.delete(company)
  end

  def belongs_to_company?(company_id)
    self.companies.where("CompanyID = #{company_id}").size > 0
  end

  def get_companies
    companies = []
    self.companies.each { |c| companies << c.CompanyID }
    companies
  end

  def county
    self.employee.company.DefaultCounty
  end

  def has_file_with_entity?(entity_id)
    Index.find(:all, group: "tblFileInfo.FileID", joins: [:file_employees, :file_entities], conditions: ["tblFileEmployees.EmployeeID = #{self.employee_id} AND tblFileEntities.EntityID = #{entity_id}"]).size > 0
  end

  def is_developer?
    [1, 231, 340, 347, 353].include?(self.employee_id)
  end

  #Needs refactoring when we figure out what the scopes are supposed to do
  def my_preferences
    return UserPreference.where("objects_id = '#{self.id}' AND objects_type = 'User'")
  end

  def my_permissions
    return UserPermission.where("user_id = #{self.id}")
  end
  #End needs refactoring

  def remove_user_related
    (self.my_preferences + self.my_permissions).each do |related|
      related.destroy
    end
  end
end
