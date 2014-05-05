class DashboardController < ApplicationController

  def index
  	@bulletins = Bulletin.all

    query = "tblFileInfo.Company = #{session[:company]} #{Index.can_view(current_user, session[:company])} AND tblFileInfo.IsClosed = 0 AND "
  	@files = Index.find(:all, group: "tblFileInfo.DisplayFileID", joins: [:file_employees], conditions: ["#{query} tblFileEmployees.EmployeeID = #{current_user.employee_id} AND is_active != 0"], order: "CAST(tblFileInfo.DisplayFileID AS UNSIGNED) DESC")

  	@favorites = Entity.find(:all, group: "tblEntities.EntityID", joins: [:employee_rolodexes], conditions: ["tblEmployeeRolodex.EmployeeID = #{current_user.employee_id} AND tblEntities.IsActive != 0 "], order: "tblEntities.FullName ASC")

  	respond_to do |format|
  		format.html { render layout: "application" }
  	end
  end

  def upload
    render nothing: true
  end
end