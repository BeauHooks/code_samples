class DocGroupsController < ApplicationController
  def create    
    @doc_group             = DocGroup.new
    @doc_group.name        = params[:name]
    @doc_group.description = params[:name]
    @doc_group.state = params[:state] if params[:state] != "All"
    @doc_group.created_by  = current_user.employee_id
    @doc_group.created_at  = Time.now.to_s(:db)
    @doc_group.updated_by  = current_user.employee_id
    @doc_group.updated_at  = Time.now.to_s(:db)
    @doc_group.save

    respond_to do |format|
      format.js { render 'doc_templates/groups' }
    end
  end

  def update_group
    @group = DocGroup.find params[:id]
    time = Time.now.to_s(:db)

    if params[:update] == "add"
      record = DocGroupTemplate.new
      record.doc_group_id = @group.id
      record.doc_template_id = params[:template]
      record.created_by = current_user.employee_id
      record.created_at = time
      record.updated_by = current_user.employee_id
      record.updated_at = time
      record.save
    else
      record = DocGroupTemplate.find params[:record]
      record.destroy
    end

    @group.updated_at = time
    @group.updated_by = current_user.employee_id
    @group.save

    @refresh = "refresh"

    respond_to do |format|
      format.js { render 'doc_groups/display_templates_not_in_group' }
    end
  end

  def display_search_results
    params[:state] != "All" ? state = "AND state = '#{params[:state]}' " : state = ""
    @results = DocGroup.where("is_active = -1 AND name LIKE '%#{params[:search]}%' #{state}").order("name ASC")
    respond_to do |format|
      format.js { render 'doc_groups/display_search_results' }
    end
  end

  def display_templates_not_in_group
    @group = DocGroup.find params[:id]

    list = ""
    @group.doc_group_templates.each do |doc|
      if list == ""
        list += "#{doc.doc_template_id}"
      else
        list += ", #{doc.doc_template_id}"
      end
    end

    if list != ""
      list = " AND id NOT IN (#{list})"
    end

    state_condition = " AND state = '#{params[:state]}' " if params[:state] != "All"
    @results = DocTemplate.where("is_active = 1 AND (short_name LIKE '%#{params[:group_search]}%' OR description LIKE '%#{params[:group_search]}%') #{state_condition} #{list}").order("description ASC")
  end

  def destroy
    group            = DocGroup.find params[:id]
    group.is_active  = 0
    group.updated_at = Time.now.to_s(:db)
    group.updated_by = current_user.employee_id
    group.save
    
    @doc_group       = DocGroup.first

    respond_to do |format|
      format.js { render 'doc_templates/groups' }
    end
  end
end