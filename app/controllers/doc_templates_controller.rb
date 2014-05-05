class DocTemplatesController < ApplicationController
  def index
    @templates = DocTemplate.all(conditions: ["is_active = ?", 1], order: "description ASC")
  end

  def doc_list
    @templates = DocTemplate.all(conditions: ["is_active = ?", 1], order: "description ASC")
    respond_to do |format|
      format.js
    end
  end

  def create
    @template = DocTemplate.new
    @version = DocTemplateVersion.new
    time = Time.now.to_s(:db)
    signers = params[:signers]
    format = params[:signature_block]

    if signers != "" && format != ""
      block = "#{signers}_#{format}"
    elsif signers != ""
      block = "#{signers}_left"
    elsif format != ""
      block = "grantor_#{format}"
    else
      block = "grantor_left"
    end

    @signature_type = DocSignatureType.where("name = '#{block}'").first

    params[:underwriter].to_i != 0 ? @template.underwriter_id = params[:underwriter].to_i : @template.underwriter_id = nil
    params[:company].to_i != 0 ? @template.company_id = params[:company].to_i : @template.company_id = nil
    @template.state = params[:state]
    @template.short_name = params[:short_name].upcase
    @template.description = params[:description]
    @template.current_version = 1
    @template.minimum_version = 1
    @template.is_editable = params[:editable].to_i
    @template.is_entity_doc = params[:entity_doc].to_i
    @template.category = params[:category]
    @template.sub_category = params[:sub_category]
    @template.created_at = time
    @template.updated_at = time
    @template.save

    @version.doc_template_id = @template.id
    @version.doc_signature_type_id = @signature_type.id
    @version.version = 1
    @version.notes = params[:note]
    @version.template_text = params[:text]
    @version.created_by = current_user.employee_id
    @version.created_at = time
    @version.updated_at = time
    @version.save

    params[:group].each do |g|
      if g[1] == "true"
        group = DocGroupTemplate.new
        group.doc_group_id = g[0].to_i
        group.doc_template_id = @template.id
        group.created_by = current_user.employee_id
        group.updated_by = current_user.employee_id
        group.created_at = Time.now.to_s(:db)
        group.updated_at = Time.now.to_s(:db)
        group.save
      end
    end

    @notice = "Template Saved"

    if params[:filter_state].blank? || params[:filter_state] == "All"
      @templates = DocTemplate.all(conditions: ["is_active = ?", 1],order: "description ASC")
    else
      @templates = DocTemplate.all(conditions: ["is_active = ? AND state = ?", 1, params[:filter_state] ],order: "description ASC")
    end

    render "doc_list"
  end

  def update
    @template =  DocTemplate.find params[:id]
    @version = DocTemplateVersion.new
    time = Time.now.to_s(:db)
    signers = params[:signers]
    format = params[:signature_block]

    if signers != "" && format != ""
      block = "#{signers}_#{format}"
    elsif signers != ""
      block = "#{signers}_left"
    elsif format != ""
      block = "grantor_#{format}"
    else
      block = "grantor_left"
    end

    @signature_type = DocSignatureType.where("name = '#{block}'").first

    params[:underwriter].to_i != 0 ? @template.underwriter_id = params[:underwriter].to_i : @template.underwriter_id = nil
    params[:company].to_i != 0 ? @template.company_id = params[:company].to_i : @template.company_id = nil
    @template.state = params[:state]
    @template.current_version += 1
    @template.minimum_version = params[:min_version]
    @template.is_editable = params[:editable].to_i
    @template.is_entity_doc = params[:entity_doc].to_i
    @template.category = params[:category]
    @template.sub_category = params[:sub_category]
    @template.created_at = time
    @template.updated_at = time
    @template.save

    @version.doc_template_id = @template.id
    @version.doc_signature_type_id = @signature_type.id
    @version.version = @template.current_version
    @version.notes = params[:note]
    @version.template_text = params[:text]
    @version.created_by = current_user.employee_id
    @version.created_at = time
    @version.updated_at = time
    @version.save

    @notice = "Template Saved"

    if params[:filter_state].blank? || params[:filter_state] == "All"
      @templates = DocTemplate.all(conditions: ["is_active = ?", 1],order: "description ASC")
    else
      @templates = DocTemplate.all(conditions: ["is_active = ? AND state = ?", 1, params[:filter_state] ],order: "description ASC")
    end

    render "doc_list"
  end

  def toggle_group
    group = DocGroupTemplate.where("doc_group_id=#{params[:group]} AND doc_template_id=#{params[:id]}").first
    if group == nil
      group = DocGroupTemplate.new
      group.doc_group_id = params[:group]
      group.doc_template_id = params[:id]
      group.created_by = current_user.employee_id
      group.updated_by = current_user.employee_id
      group.created_at = Time.now.to_s(:db)
      group.updated_at = Time.now.to_s(:db)
      group.save
    else
      group.destroy
    end

    if params[:template] != nil
      @template = DocTemplate.find params[:template]
    else
      @template = DocTemplate.find params[:id]
    end

    if params[:group] == nil
      @doc_group = DocGroup.first
    else
      @doc_group = DocGroup.find params[:group]
    end

    respond_to do |format|
      format.js { render 'toggle_group' }
    end
  end

  def new
    if params[:copy] != "" && params[:copy] != nil
      @html = DocTemplate.find(params[:copy]).doc_template_versions.last.template_text
    end
  end

  def show
    @template = DocTemplate.find params[:id]
    respond_to do |format|
      format.js
    end
  end

  def filter_by_state
    if params[:state] == "All"
      @templates = DocTemplate.all(conditions: ["is_active = ?", 1],order: "description ASC")
    else
      @templates = DocTemplate.all(conditions: ["is_active = ? AND (state = ? OR state IS NULL OR state = '')", 1, params[:state] ],order: "description ASC")
    end

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def destroy
    template = DocTemplate.find params[:id]
    template.is_active = 0
    template.save

    template.doc_group_templates.each do |group_template|
      group_template.destroy
    end

    @templates = DocTemplate.all(conditions: ["is_active = ?", 1],order: "description ASC")

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def pdf
  	#
  	# Pull in the template
  	#
  	@html = DocTemplate.first.template
  	#
  	# Get the data from source
  	#
    @fields = Hash["**FIRST_NAME**" => "David", 
    	             "**LAST_NAME**" => "White",
    	             "**ADDRESS_1**" => "60 East 300 North #1",
    	             "**CITY**" => "St. George",
                   "**STATE**" => "UT",
                   "**ZIP**" => "84770"]
    #
    # Loop through the template and replace tags with the data
    #
    @fields.each do |k,v|
      @html = @html.gsub(k, v)
    end
    #
    # Generate the PDF and send it to the user
    #
  	@pdf = PDFKit.new(@html).to_pdf
  	send_data(@pdf, filename: "doc.pdf")
  end
end