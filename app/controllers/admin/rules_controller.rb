class Admin::RulesController < AdminController
  respond_to :js, :html, :json

  # before_filter :set_options

  def index
    @rules = Rule.all
  end

  def search
    search_type = SearchType.find params[:search_type]
    @rules = Rule.search(search_type.TableField, params[:search], params[:from], params[:to])
  end

  def create
    time = Time.now.to_s(:db)
    rule = Rule.new
    rule.rule_text = params[:rule_text]
    rule.created_by = current_user.employee_id
    rule.updated_at = time
    rule.updated_by = current_user.employee_id
    rule.updated_at = time
    rule.save

    if params.has_key?(:rule_names)
      params[:rule_names].each do |position, hash|
        name = RuleName.new
        name.rule_id = rule.id
        hash.each do |k, v|
          name.send(k + "=", (v || nil) )
        end

        name.created_by = current_user.employee_id
        name.created_at = time
        name.updated_by = current_user.employee_id
        name.updated_at = time
        name.save
      end
    end

    if params.has_key?(:rule_triggers)
      params[:rule_triggers].each do |event|
        trigger = RuleTrigger.new
        trigger.rule_id = rule.id
        trigger.trigger_text = event
        trigger.created_by = current_user.employee_id
        trigger.created_at = time
        trigger.updated_by = current_user.employee_id
        trigger.updated_at = time
        trigger.save
      end
    end

    if params.has_key?(:rule_exceptions)
      params[:rule_exceptions].each do |position, hash|
        exception = RuleException.new
        exception.rule_id = rule.id
        hash.each do |k, v|
          exception.send(k + "=", (v || nil) )
        end

        exception.created_by = current_user.employee_id
        exception.created_at = time
        exception.updated_by = current_user.employee_id
        exception.updated_at = time
        exception.save
      end
    end

    @rules = [rule]
  end

  def update
    @rule = Rule.find params[:id]
    time = Time.now.to_s(:db)

    params.each do |key, value|
      unless !@rule.attributes.include?(key)
        @rule.send(key + "=", (value || nil) )
      end
    end

    if params.has_key?(:reviewed_at)
      @rule.reviewed_by = current_user.employee_id
      @refresh_view = true
    end

    @rule.updated_by = current_user.employee_id
    @rule.updated_at = time
    @rule.save
  end

  def destroy
    time = Time.now.to_s
    user = current_user.employee_id

    rule = Rule.find params[:id]
    rule.removed_at = time
    rule.removed_by = user
    rule.save

    list = ["rule_names", "rule_exceptions"]
    list.each do |symbol|
      rule.send(symbol.to_sym).each do |child|
        child.removed_at = time
        child.removed_by = user
        child.save
      end
    end

    rule.rule_triggers.each do |child|
      child.destroy
    end

    render js: "
      if($('#rules_search_result').find('.active_row').length == 0){
        $('#rules_search_result tr:first').click();
      }
    "
  end

  def show
    @rule = Rule.find params[:id]
  end

  def test
    if params[:value] == ""
      render nothing: true
    end

    trigger = params.has_key?(:trigger) && params[:trigger] != "" ? params[:trigger] : nil

    if params[:type] == "Entity ID"
      entity = Entity.find params[:value] rescue nil
      rules = entity.nil? ? [] : Rule.check_entity(entity, trigger)
      name = entity.name
    else
      rules = Rule.check_name(params[:value], trigger)
      name = params[:value]
    end

    list = ""
    rules.each do |rule|
      list += "&list[]=#{rule.rule_text.gsub(/'/, '\\\\\'').html_safe}"
    end

    if rules.size > 0
      render js: "addToQueue('rules_test', 'application/flash_notice?title=Rule Test&notice=Your test for #{params[:value].gsub(/'/, '\\\\\'')} returned with the following results:#{list}');"
    else
      render js: "addToQueue('rules_test', 'application/flash_notice?title=Rule Test&notice=Your test for #{params[:value].gsub(/'/, '\\\\\'')} returned no results.');"
    end
  end

  private

    def set_options
      @select_options = Rule::SELECT_OPTIONS
      @search_display = Rule::SEARCH_DISPLAY
    end
end