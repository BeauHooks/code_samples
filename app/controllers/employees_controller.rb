class EmployeesController < ApplicationController
  respond_to :html, :json, :js

  def index
    @employees = Employee.first
    respond_with @employees
  end

  def show
    @employee = Employee.find params[:id]
    respond_with @employee
  end

  def search
    @search_value = params[:search_value]
    @search = Employee.search do
      fulltext @search_value
    end
    @employees = @search.results
    respond_with @employees
  end
end
