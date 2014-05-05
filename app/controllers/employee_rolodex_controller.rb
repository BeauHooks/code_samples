class EmployeeRolodexController < ApplicationController
  respond_to :html, :json, :js

  def create
    rolodex = EmployeeRolodex.new
    rolodex.updated_at = Time.now.to_s(:db)
    rolodex.entered_by = current_user.employee_id
    rolodex.EmployeeID = current_user.employee_id
    rolodex.EntityID = params[:entity_id]
    rolodex.save
    render nothing: true
  end

  def destroy
    rolodex = EmployeeRolodex.where("EmployeeID = #{current_user.employee_id} AND EntityID = #{params[:entity_id]}").first
    rolodex.destroy if rolodex != nil
    render nothing: true
  end
end
