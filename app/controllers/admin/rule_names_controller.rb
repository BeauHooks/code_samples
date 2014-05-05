class Admin::RuleNamesController < AdminController
  def create
    @rule_name = RuleName.new
    @rule_name.rule_id = params[:rule_id]
    @rule_name.created_at = Time.now.to_s(:db)
    @rule_name.updated_at = Time.now.to_s(:db)
    @rule_name.created_by = current_user.employee_id
    @rule_name.updated_by = current_user.employee_id
    @rule_name.name_type = "Individual"
    @rule_name.save

    respond_to do |format|
      format.js {render "admin/rules/add_rule_name_row"}
    end
  end

  def new
    @rule_name = RuleName.new

    respond_to do |format|
      format.js {render "admin/rules/add_rule_name_row"}
    end
  end

  def destroy
    rule_name = RuleName.find params[:id]
    rule_name.removed_at = Time.now.to_s(:db)
    rule_name.removed_by = current_user.employee_id
    rule_name.save

    @rule = rule_name.rule
    respond_to do |format|
      format.js {render "admin/rules/update"}
    end
  end

  def update
    rule_name = RuleName.find params[:id]
    params.each do |key, value|
      unless !rule_name.attributes.include?(key)
        rule_name.send(key + "=", (value || nil) )
      end
    end

    rule_name.save

    @rule = rule_name.rule
    respond_to do |format|
      format.js {render "admin/rules/update"}
    end
  end
end