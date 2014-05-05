class FileEmployeesController < ApplicationController
  respond_to :html, :json, :js
  before_filter :file_employee_types, :employees, only: [:create, :destroy, :update]

  def index
  end

  def show
  end

  def new
  end

  def create
    @file = Index.find params[:index_id]

    if @permission_add_employee_to_index || @file.has_employee?(current_user.employee_id)
      employee = Employee.find(current_user.employee_id)
      file_employee               = @file.file_employees.build
      file_employee.FileID        = @file.FileID
      file_employee.DisplayFileID = @file.DisplayFileID
      file_employee.EmployeeID    = current_user.employee_id
      file_employee.Position      = FileEmployeeType.find(params[:position]).TypeDescription if params.has_key?(:position)
      file_employee.save!
    else
      flash[:error] = "You cannot add employee's to files you don't belong to!"
      render nothing: true
    end
  end

  def edit
  end

  def update
    file_employee = FileEmployee.find params[:id]
    @file = file_employee.index

    if !file_employee.employee.has_permission?(:can_close_files, company: @file.Company) && params[:Position] && params[:Position].include?("Closer")
      flash[:error] = "#{file_employee.employee.FullName} cannot be added as a closer to this file. Your changes have been undone."
      return
    end

    file_employee.update_attributes(file_employee.dup.attributes.merge params.select { |k| file_employee.dup.attributes.keys.include? k })
    render nothing: true
  end

  def destroy
    file_employee = FileEmployee.find params[:id]
    file_employee.is_active = 0
    file_employee.deactivated_by = current_user.employee_id
    file_employee.save!
    @file = file_employee.index
  end

  private

  def employees
    @employees = Employee.closers(session[:company], @permission_lock_files)
  end

  def file_employee_types
    if @permission_lock_files
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Opened Order')")
    else
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Searcher', 'Opened Order')")
    end
  end
end
