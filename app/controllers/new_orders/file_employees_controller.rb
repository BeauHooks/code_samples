class NewOrders::FileEmployeesController < NewOrdersController
  before_filter :get_employee_types
  before_filter :get_employees, except: [:show_all_employees]

  def create
    @file = Index.find(params[:new_order_id])
    @file_employee = @file.file_employees.create
  end

  def destroy
    file_employee = FileEmployee.find(params[:id])
    file_employee.destroy
    render nothing: true
  end

  def show_all_employees
    @file = Index.find(params[:new_order_id])
    if params[:show_all_employees]
      @employees = Employee.all
    else
      @employees = Employee.closers(session[:company], @permission_lock_files)
    end
  end

  private

  def get_employees
    @employees = Employee.closers(session[:company], @permission_lock_files)
  end

  def get_employee_types
    if @permission_lock_files
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Opened Order')")
    else
      @file_employee_types = FileEmployeeType.find(:all, order: "TypeDescription ASC", conditions: "TypeDescription NOT IN ('Searcher', 'Opened Order')")
    end
  end
end