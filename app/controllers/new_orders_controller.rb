class NewOrdersController < ApplicationController
  def check_in_progress
    @in_progress = Index.in_progress(current_user.employee_id)
  end
end