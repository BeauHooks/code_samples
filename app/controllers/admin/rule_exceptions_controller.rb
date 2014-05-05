class Admin::RuleExceptionsController < AdminController
  def create
  	@exception = RuleException.new
  	@exception.rule_id = params[:rule_id]
      @exception.match_field = "EntityID"
      @exception.match_operator = "Equal To"
  	@exception.created_by = current_user.employee_id
  	@exception.created_at = Time.now.to_s(:db)
  	@exception.updated_by = current_user.employee_id
  	@exception.updated_at = Time.now.to_s(:db)
  	@exception.save

  	respond_to do |format|
  		format.js {render "admin/rules/add_rule_exception_row"}
  	end
  end

  def new
    @exception = RuleException.new

    respond_to do |format|
      format.js {render "admin/rules/add_rule_exception_row"}
    end
  end

  def update
  	exception = RuleException.find params[:id]

	params.each do |key, value|
		unless !exception.attributes.include?(key)
			exception.send(key + "=", (value || nil) )
		end
	end
	exception.save

	render nothing: true
  end

  def destroy
  	@exception = RuleException.find params[:id]
  	@exception.removed_at = Time.now.to_s(:db)
  	@exception.removed_by = current_user.employee_id
  	@exception.save

  	render nothing: true
  end
end