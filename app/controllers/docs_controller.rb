class DocsController < ApplicationController
  include ActionView::Helpers::NumberHelper

  def zoom
  end

  def refresh_input_fields
    @file = Index.where("FileID = #{params[:file_id]}").first
  end

  def update_notary_vesting
    @doc_entity = FileDocEntity.find params[:id]
    @file = Index.where("FileID = #{@doc_entity.file_id}").first

    if params[:update_tree_notary]
      # Mark the existing fields inactive so that they are updated later on.
      fields = @file.file_doc_fields.where("is_active = 1 AND doc_id = #{@doc_entity.doc_id} AND tag LIKE '#{@doc_entity.tag}_NOTARY_%#{@doc_entity.id}' and tag NOT LIKE '%TREE%' ")
      if fields.size > 0
        fields.each do |field|
          field.is_active = 0
          field.save
        end
      end

    end
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)
  end

  def quick_add
    @file   = Index.where("FileID = #{params[:file_id]}").first
    @doc_id = 0

    if params[:template] != nil
      state = Company.find(@file.Company).CompanyState
      @template = DocTemplate.where("short_name = '#{params[:template]}' AND (state = '#{state}')").first

      if @template == nil
        @template = DocTemplate.where("short_name = '#{params[:template]}' ").first
      end
    else
      @template = DocTemplate.find params[:template_id]
    end

    if @file.file_doc_fields.size == 0
      initialize_standard_fields
    end

    respond_to do |format|
      format.js { render 'transfer_to_create_method' }
    end
  end

  def create
    @file = Index.find_by_FileID(params[:file_id])
    other_standard = ["ACK", "TPA", "RF", "TCI", "TDS", "TD", "TDL", "TDN", "SL", "BL"]
    @run_1099 = nil

    case params[:type]
    when "Template"
      if params[:quickadd] == nil
        @template = DocTemplate.find params[:template_id]
      else
        @template = DocTemplate.find params[:quickadd]
      end

      if @file.file_doc_fields.size == 0
        initialize_standard_fields
      end

      if params[:doc_entity_id] != "all"
        doc                       = Doc.new
        doc.file_id               = @file.FileID
        doc.company_id            = @file.Company
        doc.doc_template_id       = @template.id
        doc.doc_signature_type_id = @template.doc_template_versions.where(version: @template.current_version).first.doc_signature_type_id
        doc.doc_template_version  = @template.current_version
        doc.description           = @template.description
        doc.template_text         = @template.doc_template_versions.where(version: @template.current_version).first.template_text
        doc.created_by            = current_user.employee_id
        doc.updated_by            = current_user.employee_id

        if params[:doc_entity_id] != nil || params[:entity_id] != nil
          if params[:doc_entity_id]
            doc_entity = FileDocEntity.find params[:doc_entity_id]
          else
            doc_entity = FileDocEntity.where("entity_id = #{params[:entity_id]}").first
            if doc_entity == nil
              doc_entity = FileDocEntity.new
              doc_entity.doc_id = 0
              doc_entity.file_id = @file.FileID
              doc_entity.entity_id = params[:entity_id]
              doc_entity.is_active = 1
              doc_entity.tag = "CUSTOM_#{@template.short_name}"
              doc_entity.created_by = current_user.employee_id
              doc_entity.updated_by = current_user.employee_id
              doc_entity.save
            end
          end
          doc.doc_entity_id = doc_entity.id
          doc.description = doc_entity.entity.name
        end

        if @template.short_name == "HUD" || @template.short_name == "SS" || @template.short_name == "LSS"
          if @file.SentForFunding == nil
            if @template.short_name == "SS"
              settlement_statement = Hash.new
              settlement_statement[:index_id] = @file.ID
              settlement_statement[:created_by] = current_user.employee_id
              settlement_statement[:updated_by] = current_user.employee_id
              ss = SettlementStatement.create_from_template("default", settlement_statement)
              doc.settlement_statement_id = ss.id
            elsif  @template.short_name == "LSS"
              hud = create_hud(doc, "loan-in-house")
              doc.hud_id = hud.id
            else
              hud = create_hud(doc)
              doc.hud_id = hud.id
            end
          else
            @cannot_create = true
          end
        end

        if other_standard.include?(@template.short_name)
          initialize_other_standard_doc_fields(doc)
        end

        doc.save
      else
        if params[:tag] == "all"
          tag = ""
        else
          tag = " AND tag = '#{params[:tag]}'"
        end

        @file.file_doc_entities.where("is_active = 1 AND doc_id = 0 #{tag}").each do |entity|
          doc                       = Doc.new
          doc.file_id               = @file.FileID
          doc.company_id            = @file.Company
          doc.doc_template_id       = @template.id
          doc.doc_signature_type_id = @template.doc_template_versions.where("version = #{@template.current_version}").first.doc_signature_type_id
          doc.doc_template_version  = @template.current_version
          doc.description           = entity.entity.full_name
          doc.template_text         = @template.doc_template_versions.where("version = #{@template.current_version}").first.template_text
          doc.created_by            = current_user.employee_id
          doc.updated_by            = current_user.employee_id
          doc.doc_entity_id         = entity.id

          doc.save
          initialize_doc_fields(doc)
        end
      end
      @doc = doc
    when "Group"
      @group     = DocGroup.find params[:group_id]
      @templates = @group.doc_group_templates

      if @file.file_doc_fields.size == 0 && @templates.size > 0
        initialize_standard_fields
      end

      @templates.each do |t|
        template = DocTemplate.find t.doc_template_id

        if template.is_entity_doc == 1
          signature = template.doc_template_versions.order("version DESC").first.doc_signature_type.name.split("_")[0]

          case signature
          when "grantor"
            tag = "AND tag = 'GRANTOR'"
          when "grantee"
            tag = "AND tag = 'GRANTEE'"
          else
            tag = "AND tag in ('GRANTOR', 'GRANTEE')"
          end

          entities = @file.file_doc_entities.where("is_active = 1 AND doc_id = 0 #{tag}")

          if template.short_name == "1099" && entities.count > 1
            @run_1099 = true
          else
            entities.each do |entity|
              doc                       = Doc.new
              doc.file_id               = @file.FileID
              doc.company_id            = @file.Company
              doc.doc_entity_id         = entity.id
              doc.doc_template_id       = template.id
              doc.doc_signature_type_id = template.doc_template_versions.where("version = #{template.current_version}").first.doc_signature_type_id
              doc.doc_template_version  = template.current_version
              doc.description           = entity.entity.full_name
              doc.template_text         = template.doc_template_versions.where("version = #{template.current_version}").first.template_text
              doc.created_by            = current_user.employee_id
              doc.updated_by            = current_user.employee_id
              doc.save
              initialize_doc_fields(doc)
            end
          end
        else
          doc                       = Doc.new
          doc.file_id               = @file.FileID
          doc.company_id            = @file.Company
          doc.doc_template_id       = template.id
          doc.doc_signature_type_id = template.doc_template_versions.where("version = #{template.current_version}").first.doc_signature_type_id
          doc.doc_template_version  = template.current_version
          doc.description           = template.description
          doc.template_text         = template.doc_template_versions.where("version = #{template.current_version}").first.template_text
          doc.created_by            = current_user.employee_id
          doc.updated_by            = current_user.employee_id

          if other_standard.include?(template.short_name)
            initialize_other_standard_doc_fields(doc)
          end

          doc.save
        end
      end
    when "Prior"
    end

    @doc_list = @file.docs.find(:all, conditions: ["docs.is_active = -1"], include: [:doc_template], order: ["doc_templates.short_name ASC"])

    @file.file_doc_entities.each do |i|
      i.file_doc_entity_signatures.where("name IS NULL AND signature IS NULL AND is_active = 0").each do |j|
        j.destroy
      end
    end

    if @doc_list.size > 0
      @template        = @file.docs.order("updated_at DESC").first.template_text
      @file_doc_fields = @file.file_doc_fields
      @fields          = generate_doc_fields(@file.docs)
      @field_array     = generate_doc_fields(@file.docs)
    end

    if @run_1099 != nil
      @file   = Index.where("FileID = #{params[:file_id]}").first
      @template = DocTemplate.where("short_name = '1099'").first
    end

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def update
    @doc                      = Doc.find params[:id]
    update                    = @doc.doc_template.current_version
    @doc.doc_template_version = update
    @doc.template_text        = @doc.doc_template.doc_template_versions.where("version = #{update}").first.template_text
    @doc.updated_by           = current_user.employee_id
    @doc.updated_at           = Time.now.to_s(:db)
    @doc.save

    respond_to do |format|
      format.js { render 'show_doc' }
    end
  end

  def update_all
    @file = Index.where("FileID = #{params[:file_id]}").first
    @doc_list = @file.docs.find(:all, conditions: ["docs.is_active = -1"], include: [:doc_template], order: ["doc_templates.short_name ASC"])

    @doc_list.each do |doc|
      if doc.has_update?
        update                   = doc.doc_template.current_version
        doc.doc_template_version = update
        doc.template_text        = doc.doc_template.doc_template_versions.where("version = #{update}").first.template_text
        doc.updated_by           = current_user.employee_id
        doc.updated_at           = Time.now.to_s(:db)
        doc.save
      end
    end

    if @doc_list.size > 0
      @template        = @file.docs.first.template_text
      @file_doc_fields = @file.file_doc_fields
      @field_array     = generate_doc_fields(@file.docs)
    end

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def update_related
      case params[:field]
      when "grantor_signatures", "grantee_signatures"
          tag = params[:field].sub("_signatures", "")
          name_list = []
          id_list = []
          FileDocEntity.where("file_id= #{params[:file_id]} AND doc_id = 0 AND is_active != 0 AND tag = '#{tag.upcase}'").order("sort_order ASC").each do |doc_entity|
              signature = doc_entity.rolodex_signature
              name = signature.rolodex_signature_entities.where("parent_id = 0").first.name.to_s unless signature.blank?
              name_list << name unless name.blank?
              id_list << doc_entity.id

              unless signature.blank?
                FileDocField.where("file_id = #{params[:file_id]} AND is_active != 0 AND doc_id = 0 AND tag = 'W9_NAME_#{doc_entity.id}'").each do |field|
                  field.value = name
                  field.save
                end
              end
          end

          unless id_list.size == 0
            Index.where("FileID = #{params[:file_id]}").first.docs.where("doc_entity_id IN (#{id_list.join(", ")})").each do |doc|
              next unless doc.doc_template.short_name == "1099"
              doc_entities = FileDocEntity.where("doc_id = #{doc.id} AND is_active != 0 AND tag = '#{tag.upcase}' ").order("sort_order ASC")
              if doc_entities.size == 0
                doc_entities = FileDocEntity.where("id = #{doc.doc_entity_id}")
              end
              doc_name_list = []
              doc_entities.each do |doc_entity|
                signature = doc_entity.rolodex_signature
                name = signature.rolodex_signature_entities.where("parent_id = 0").first.name.to_s unless signature.blank?

                if doc_name_list.size == 0 && doc_entity.entity.IndCorp == "Individual"
                  full = name.split(" ")
                  name = full[-1] + ", " + full[0...-1].join(" ")
                end

                doc_name_list << name unless name.blank?
              end
              name = doc_name_list.join(" and ")


              FileDocField.where("file_id = #{params[:file_id]} AND is_active != 0 AND doc_id = 0 AND tag = '1099_SELLER_NAME_#{doc.doc_entity_id}' ").each do |field|
                field.value = name
                field.save
              end
            end
          end

          names = name_list.size < 3 ? name_list.join(" and ") : name_list[0...-1].join(", ") + ", and " + name_list[-1]
          update_notary(params[:file_id], "#{tag.upcase}", 0)
          notary = FileDocField.where("file_id = #{params[:file_id]} AND tag = '#{tag.upcase}_NOTARY_VESTING' AND doc_id=0").first.value

         render js: "
              $('##{tag}_names').val('#{names.html_safe}').change();
              $('##{tag}_vesting').val('#{names.html_safe}').change();
              $('##{tag}_notary_vesting').val('#{notary.html_safe}').change();
          "
      else
        render nothing: true
      end
  end

  def edit_description
    @doc = Doc.find params[:id]
  end

  def update_description
    @doc = Doc.find params[:id]

    if params[:description] != nil && params[:description] != "" && params[:description] != @doc.description
      @doc.description = params[:description]
      @doc.updated_at  = Time.now.to_s(:db)
      @doc.updated_by  = current_user.employee_id
      @doc.save
    end

    respond_to do |format|
      format.js { render 'update_description' }
    end

  end

  def create_custom
    @file  = Index.find params[:file_id]
    @value = params[:value].html_safe
    @field = params[:field].gsub("global_", "").gsub("custom_", "").upcase

    # Update 1099 if it exists for this doc
    # if @field.split("_")[0] == "1099" || @field.split("_")[0..1].join("_") == "CB_1099"
    #   doc = Doc.where("doc_entity_id = #{@field.split("_")[-1]} AND filing_1099_id IS NOT NULL").first
    #   update_1099(doc, doc_field, doc_field.value) if doc != nil && doc_field != nil && doc.filing_1099_id != nil
    # end

    # if ["FULL_PROPERTY_ADDRESS", "GRANTOR_SIGNING_DATE"].include?(@field)
    #   @file.docs.where("filing_1099_id IS NOT NULL").each do |doc|
    #     update_1099(doc, doc_field, doc_field.value) if doc_field != nil
    #   end
    # end

    if @file.file_doc_fields.where("tag = '#{@field}' AND doc_id = #{params[:doc_id]} AND is_active = 1").last == nil
      doc_field = FileDocField.new
      # to_save   = record_exists

      doc_field.doc_id     = params[:doc_id]
      doc_field.file_id    = @file.FileID
      doc_field.tag        = @field
      doc_field.value      = params[:value]
      doc_field.is_active  = 1
      doc_field.created_by = current_user.employee_id
      doc_field.created_at = Time.now.to_s(:db)
      doc_field.updated_by = current_user.employee_id
      doc_field.updated_at = Time.now.to_s(:db)

      # if to_save == true
        doc_field.save
      # end

    else
      doc_field            = @file.file_doc_fields.where("tag = '#{@field}' AND doc_id = #{params[:doc_id]} ").last
      doc_field.is_active  = 1
      doc_field.value      = params[:value]
      doc_field.updated_by = current_user.employee_id
      doc_field.updated_at = Time.now.to_s(:db)
      doc_field.save
    end

    begin
      if (@field.split("_")[1..-2].join("_") == "TAX_ID" || @field.split("_")[-2] == "SSN") && params[:doc_id] == "0"
        doc_entity = FileDocEntity.find @field.split("_")[-1]
        entity     = Entity.find doc_entity.entity_id
        note       = EntityNote.new

        note.EntityID = entity.EntityID
        note.NoteDT   = Time.now.to_s(:db)
        note.TakenBy  = current_user.employee_id
        if entity.IndCorp == "Individual"
          note.NoteText = "Changed SSN from '#{entity.TaxID}' to '#{params[:value]}'"
        else
          note.NoteText = "Changed TAX ID from '#{entity.TaxID}' to '#{params[:value]}'"
        end
        note.IsPrivate = -1
        note.save

        entity.TaxID = params[:value]
        entity.save

        entity.IndCorp != "Individual" ? condition = "tag NOT LIKE 'W9_SSN%'" : condition = "tag NOT LIKE 'W9_TAX%'"
        @file.file_doc_fields.where("tag LIKE '%_#{@field.split("_")[-1]}' AND (tag LIKE '%TAX_ID%' OR tag LIKE '%SSN%') AND #{condition} AND doc_id=0 AND is_active = 1").each do |field|
          field.value = params[:value]
          field.save
        end
      end
    rescue ""

    end

    if ["PROPERTY_ADDRESS", "PROPERTY_CITY", "PROPERTY_STATE"].include?(@field)
      property_address = @file.file_doc_fields.where("tag = 'FULL_PROPERTY_ADDRESS' and doc_id = 0").first.value
      render js: "$('#property_contents #full_property_address').val('#{property_address}').change();"
    else
      render nothing: true
    end
  end

  def import_from_pr
    file = Index.find params[:file_id]
    type = params[:type]

    pr = file.property_reports.last

    unless pr == nil
      case type
      when "GRANTOR"
        @value = pr.TextVesting
      when "GRANTEE"
        @value = pr.Policy1ProposedInsured
      end
      render js: "$('##{type.downcase}_vesting').val('#{@value.to_s.html_safe}').change();"
    else
      render nothing: true
    end
  end

  def update_settlement_dates
    file = Index.where("FileID = #{params[:file_id]}").first
    tags = ["GRANTOR_SIGNING_DATE", "GRANTEE_SIGNING_DATE", "GRANTOR_NOTARY_DATE", "GRANTEE_NOTARY_DATE"]
    updates = []

    tags.each do |tag|
      field = file.file_doc_fields.where("tag = '#{tag}' AND doc_id = 0").first
      if tag.include?("SIGNING")
        field.value = params[:value]
      else
        field.value = get_written_date(params[:value], "input")
      end

      updates << field.value

      field.updated_at = Time.now.to_s(:db)
      field.updated_by = current_user.employee_id
      field.save
    end

    render js: "
      $('#grantor_signing_date').val('#{updates[0]}');
      $('#grantee_signing_date').val('#{updates[1]}');
      $('#grantor_notary_date').val('#{updates[2]}');
      $('#grantee_notary_date').val('#{updates[3]}');
      countMissingFields();
    "
  end

  def revert_to_global
    @file = Index.find params[:file_id]
    tag = params[:field].gsub("global_", "").gsub("custom_", "").upcase
    @field = @file.file_doc_fields.where("tag = '#{tag}' AND is_active = 1 AND doc_id = #{params[:doc_id]}").first

    if @file.file_doc_fields.where("tag = '#{tag}' AND is_active = 1 AND doc_id = 0").first == nil
      @global         = FileDocField.new
      @global.doc_id  = 0
      @global.file_id = @file.FileID
      @global.tag     = tag
      if @field != nil
        @global.value = @field.value
      else
        @global.value = ""
      end
      @global.is_active  = 1
      @global.created_by = current_user.employee_id
      @global.created_at = Time.now.to_s(:db)
      @global.updated_at = Time.now.to_s(:db)
      @global.updated_by = current_user.employee_id
      @global.save
    end

    if @field != nil
      @field.is_active  = 0
      @field.updated_at = Time.now.to_s(:db)
      @field.updated_by = current_user.employee_id
      @field.save
    end

    # Update 1099 if it exists for this doc
    if tag.split("_")[0] == "1099"|| tag.split("_")[0..1].join("_") == "CB_1099"
      doc = Doc.where("doc_entity_id = #{tag.split("_")[-1]} AND filing_1099_id IS NOT NULL").first
      field = @file.file_doc_fields.where("tag = '#{tag}' AND is_active = 1 AND doc_id = 0").first
      update_1099(doc, field, field.value) if doc != nil && field != nil && doc.filing_1099_id != nil
    end

    if ["FULL_PROPERTY_ADDRESS", "GRANTOR_SIGNING_DATE"].include?(tag)
      field = @file.file_doc_fields.where("tag = '#{tag}' AND is_active = 1 AND doc_id = 0").first
      @file.docs.where("filing_1099_id IS NOT NULL").each do |doc|
        update_1099(doc, field, field.value) if field != nil
      end
    end

    render nothing: true
  end

  def display_address_results
    @entity = Entity.find params[:entity_id]
    @file = Index.find params[:file_id]
    @tag = params[:tag]
  end

  def display_address_entry
    @file = Index.find params[:file_id]
    @tag = params[:tag]
    @entity = Entity.find params[:entity_id] if params[:entity_id] != ""

    case params[:address_id]
    when "new"
      @address = ["", "", "", "", "", ""]
    when "property"
      @address = []
      list = ["PROPERTY_ADDRESS", "", "PROPERTY_CITY", "PROPERTY_STATE", "PROPERTY_ZIP", "PROPERTY_COUNTY"]

      list.each do |tag|
        tag != "" ? value = @file.file_doc_fields.where("doc_id = 0 AND is_active = 1 AND tag = '#{tag}' ").first.value : value = ""
        @address << value
      end
    when "current"
      @address = []
      list = ["_ADDRESS_1", "_ADDRESS_2", "_CITY", "_STATE", "_ZIP", "_COUNTY"]

      list.each do |tail|
        tail != "" ? value = @file.file_doc_fields.where("doc_id = 0 AND is_active = 1 AND tag = '#{@tag}#{tail}' ").first.value : value = ""
        @address << value
      end
    else
      address = EntityContact.find params[:address_id]
      @address = [address.Address, address.Address2, address.City, address.State, address.Zip, address.County]
      @contact_id = address.ContactID
    end
  end

  def update_address
    @file = Index.find params[:file_id]
    @tag = params[:tag].upcase
    fields = @file.file_doc_fields.where("tag in ('#{@tag}_ADDRESS_1', '#{@tag}_ADDRESS_2', '#{@tag}_CITY', '#{@tag}_STATE', '#{@tag}_ZIP', '#{@tag}_COUNTY')")
    @update_fields = []

    if params[:commit] == "Save"
      entity = Entity.find params[:entity_id]

      if ["current", "property", "new"].include?(params[:address_id])
        note_text = "NEW Address from Doc - #{params[:address_1]}#{ ", #{params[:address_2]}" if params[:address_2] != "" }, #{params[:city]}, #{params[:state]} #{params[:zip]}"
        params[:address_1] != "" ? description = params[:address_1] : description = nil
        entity.IndCorp == "Individual" ? contact_desc = "Home" : contact_desc = "Office"
      else
        old_address = EntityContact.find params[:address_id]
        old_address.IsInactive = -1
        old_address.IsActive = 0
        old_address.save
        description = old_address.description
        contact_desc = old_address.ContactDesc
        note_text = "UPDATE Address from Doc - OLD: #{old_address.Address}#{ ", #{old_address.Address2}" if old_address.Address2 != "" }, #{old_address.City}, #{old_address.State} #{old_address.Zip}.  NEW: #{params[:address_1]}#{ ", #{params[:address_2]}" if params[:address_2] != "" }, #{params[:city]}, #{params[:state]} #{params[:zip]}"
      end

      @address = EntityContact.new
      @address.EntityID = params[:entity_id]
      @address.ContactType = "ADDRESS"
      @address.Description = description
      @address.ContactDesc = contact_desc
      @address.EnteredBy = current_user.employee_id
      @address.EnteredDT = Time.now.to_s(:db)
      @address.Address = params[:address_1]
      @address.Address2 = params[:address_2]
      @address.City = params[:city]
      @address.State = params[:state]
      @address.Zip = params[:zip]
      @address.County = params[:county]

      if entity.entity_contacts.where("IsActive = -1 AND IsInactive = 0 AND IsPrimary = -1").size == 0
        @address.Primary = -1
        @address.IsPrimary = -1
      end
      @address.save

      note = EntityNote.new
      note.EntityID = entity.EntityID
      note.NoteDT   = Time.now.to_s(:db)
      note.TakenBy  = current_user.employee_id
      note.NoteText = note_text
      note.save
    end

    fields.each do |field|
      case field.tag.gsub("GRANTOR_", "").gsub("GRANTEE_", "")
      when "ADDRESS_1"
        value = params[:address_1]
      when "ADDRESS_2"
        value = params[:address_2]
      when "CITY"
        value = params[:city]
      when "STATE"
        value = params[:state]
      when "ZIP"
        value = params[:zip]
      when "COUNTY"
        value = params[:county]
      end
      @update_fields << [field.tag.downcase, value]
    end
  end

  def create_signature
    @doc_signature = FileDocEntitySignature.find params[:id]
    @doc_entity = FileDocEntity.find @doc_signature.doc_entity_id
    @file = Index.where("FileID = #{@doc_entity.file_id}").first
    value    = params[:value]
    type = params[:type]
    field = params[:field]
    position = 0

    while true
      if @doc_entity.file_doc_entity_signatures.last != nil
        if @doc_entity.file_doc_entity_signatures.last.name == value
          break
        end
      end

      position += 1
      if @doc_entity.file_doc_entity_signatures.where("sort_order=#{position} AND is_active=1 ").first == nil
          @doc_signature.is_active  = -1
          @doc_signature.sort_order = position
          @doc_signature.created_by = current_user.employee_id
          @doc_signature.created_at = Time.now.to_s(:db)
          @doc_signature.updated_by = current_user.employee_id
          @doc_signature.updated_at = Time.now.to_s(:db)
          if field == "name"
            @doc_signature.name      = params[:value]
            @doc_signature.signature = params[:value]
          elsif field == "signature"
            @doc_signature.signature = params[:value]
          end
          @doc_signature.save
        break
      end
    end

    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)
    respond_to do |format|
      format.js { render 'update_notary_vesting' }
    end
  end

  def update_signature
    @doc_entity = FileDocEntity.find params[:id]
    @file = Index.where("FileID = #{@doc_entity.file_id}").first

    @doc_signature  =  @doc_entity.rolodex_signature.rolodex_signature_entities.where("primary = 0").first
    @doc_signature.updated_at = Time.now.to_s(:db)
    @doc_signature.updated_by = current_user.employee_id

    if params[:field] == "signature_name"
      @doc_signature.name  = params[:value]
    else
      @doc_signature.signature  = params[:value]
    end

    @doc_signature.save

    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)
    respond_to do |format|
      format.js { render 'update_notary_vesting' }
    end
  end

  def signature_preview
    @doc = Doc.find params[:id]
  end

  def change_signature_block
    @signature = DocSignatureType.where("name = '#{params[:signer]}_#{params[:format]}'").first
    @doc = Doc.find params[:id]

    if @signature != nil
      @doc.doc_signature_type_id = @signature.id
      @doc.updated_by = current_user.employee_id
      @doc.updated_at = Time.now.to_s(:db)
      @doc.save
    end

    render action: 'signature_preview'
  end

  def update_entity_position
    @mover = FileDocEntity.find params[:id]
    @file = Index.where("FileID = #{@mover.file_id}").first
    @direction = ""
    new_sort = params[:new_sort].to_i rescue 0

    all = @file.file_doc_entities.where("is_active = 1 AND tag='#{@mover.tag}' AND doc_id = #{@mover.doc_id}").order("sort_order ASC")
    if new_sort > all.size
      new_sort = all.last.sort_order
    end

    unless new_sort == 0
      new_sort > @mover.sort_order ? @direction = "down" : @direction = "up"
    end

    case @direction
    when "up" # Up as in moving from 2 to 1
      if @mover.sort_order > 1
        @file.file_doc_entities.where("is_active = 1 AND tag='#{@mover.tag}' AND doc_id = #{@mover.doc_id} AND sort_order >= #{new_sort} AND sort_order < #{@mover.sort_order}").each do |shaker|
          shaker.sort_order += 1
          shaker.updated_at = Time.now.to_s(:db)
          shaker.updated_by = current_user.employee_id
          shaker.save
        end

        @mover.sort_order = new_sort
        @mover.updated_by = current_user.employee_id
        @mover.updated_at = Time.now.to_s(:db)
        @mover.save
      end
    when "down" # Down as in moving from 1 to 2
      if @mover.sort_order < @file.file_doc_entities.where("is_active = 1 AND tag='#{@mover.tag}' AND doc_id = #{@mover.doc_id} ").count
        @file.file_doc_entities.where("is_active = 1 AND tag='#{@mover.tag}' AND doc_id = #{@mover.doc_id} AND sort_order <= #{new_sort} AND sort_order > #{@mover.sort_order}").each do |shaker|
          shaker.sort_order -= 1
          shaker.updated_at = Time.now.to_s(:db)
          shaker.updated_by = current_user.employee_id
          shaker.save
        end

        @mover.sort_order = new_sort
        @mover.updated_by = current_user.employee_id
        @mover.updated_at = Time.now.to_s(:db)
        @mover.save
      end
    end

    @doc_entity = @mover
    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)
    respond_to do |format|
      format.js { render 'update_notary_vesting' }
    end
  end

  def update_signature_position
    @mover = FileDocEntitySignature.find params[:id]
    @doc_entity = FileDocEntity.find @mover.doc_entity_id
    @file = Index.where("FileID = #{@doc_entity.file_id}").first
    @direction = ""
    new_sort = params[:new_sort].to_i rescue 0

    all = @doc_entity.file_doc_entity_signatures.where("is_active = -1").order("sort_order ASC")
    if new_sort > all.size
      new_sort = all.last.sort_order
    end

    unless new_sort == 0
      new_sort > @mover.sort_order ? @direction = "down" : @direction = "up"
    end

    case @direction
    when "up" # Up as in moving from 2 to 1
      if @mover.sort_order > 1
        @doc_entity.file_doc_entity_signatures.where("is_active = -1 AND sort_order >= #{new_sort} AND sort_order < #{@mover.sort_order}").each do |shaker|
          shaker.sort_order += 1
          shaker.updated_at = Time.now.to_s(:db)
          shaker.updated_by = current_user.employee_id
          shaker.save
        end

        @mover.sort_order = new_sort
        @mover.updated_by = current_user.employee_id
        @mover.updated_at = Time.now.to_s(:db)
        @mover.save
      end
    when "down" # Down as in moving from 1 to 2
      if @mover.sort_order < @doc_entity.file_doc_entity_signatures.where("is_active = -1").count
        @doc_entity.file_doc_entity_signatures.where("is_active = -1 AND sort_order <= #{new_sort} AND sort_order > #{@mover.sort_order}").each do |shaker|
          shaker.sort_order -= 1
          shaker.updated_at = Time.now.to_s(:db)
          shaker.updated_by = current_user.employee_id
          shaker.save
        end

        @mover.sort_order = new_sort
        @mover.updated_by = current_user.employee_id
        @mover.updated_at = Time.now.to_s(:db)
        @mover.save
      end
    end

    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)
    respond_to do |format|
      format.js { render 'update_notary_vesting' }
    end
  end

  def edit_custom_field
    @file  = Index.find params[:file_id]
    @doc   = Doc.find params[:doc_id]
    @field = params[:field]

    field = @doc.file_doc_fields.where("tag = '#{@field.gsub('global_', '').gsub('custom_', '').upcase}' AND is_active != 0").first
    field = @file.file_doc_fields.where("tag = '#{@field.gsub('global_', '').gsub('custom_', '').upcase}' AND doc_id = 0 AND is_active != 0").first if field.blank?
    @value = field.blank? ? "" : field.value.html_safe
  end

  def update_entity_signature
    @doc_entity = FileDocEntity.find params[:id]
    @file = Index.where("FileID = #{@doc_entity.file_id}").first
    if params[:force_create] == "true"
      @force_create = true
    end

    if params[:value] != "new"
      @doc_entity.rolodex_signature_id = params[:value] if params[:value] != nil && params[:value] != ""
      @doc_entity.updated_by           = current_user.employee_id
      @doc_entity.updated_at           = Time.now.to_s(:db)
      @doc_entity.save

      @file.file_doc_fields.where("doc_id = #{@doc_entity.doc_id} AND is_active = 1 AND tag LIKE '%NOTARY_%#{@doc_entity.id}_TREE%' ").each do |field|
        field.is_active  = 0
        field.updated_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.save
      end

      @file.file_doc_fields.where("doc_id = #{@doc_entity.doc_id} AND is_active = 1 AND tag LIKE '%NOTARY_VESTING%#{@doc_entity.id}' AND tag NOT LIKE '%NOTARY_%#{@doc_entity.id}_TREE%' ").each do |field|
        field.value = create_notary(@doc_entity, "entity")
        field.save
      end

      # Updates the appropriate notary field with changes to entities and signatures
      update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)
      @update_notary = true
      respond_to do |format|
        format.js { render 'update_entity_signature' }
      end
    else
      @entity_id = @doc_entity.entity_id

      respond_to do |format|
        format.js { render 'rolodex_signatures/new' }
      end
    end
  end

  def add_entity
    @file = Index.find params[:file_id]
    @section = params[:section]
    (params[:doc_id] == "" || params[:doc_id] == nil) ? @doc_id = 0 : @doc_id = params[:doc_id]

    respond_to do |format|
      format.js { render 'add_entity' }
    end
  end

  def add_sub_entity
    @doc_entity                  = FileDocEntity.find params[:id]
    @doc_signature               = FileDocEntitySignature.new
    @doc_signature.doc_entity_id = @doc_entity.id
    @doc_signature.name          = @doc_entity.entity.name
    @doc_signature.is_active     = -1
    @doc_signature.created_at    = Time.now.to_s(:db)
    @doc_signature.created_by    = current_user.employee_id
    @doc_signature.updated_at    = Time.now.to_s(:db)
    @doc_signature.updated_by    = current_user.employee_id

    if @doc_entity.file_doc_entity_signatures.where("is_active = -1").last == nil
      @doc_signature.sort_order = 1
    else
      @doc_signature.sort_order = @doc_entity.file_doc_entity_signatures.where("is_active = -1").order("sort_order ASC").last.sort_order + 1
    end

    @doc_signature.save
    @file = Index.where("FileID = #{@doc_entity.file_id}").first
    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)

    respond_to do |format|
      format.js { render 'add_sub_entity' }
    end
  end

  def create_entity
    if params[:entity_id] == ""
      render nothing: true
      return
    end

    @file = Index.find params[:file_id]
    @section = params[:section]
    @doc_id                = params[:doc_id].to_i if params[:doc_id] != nil
    tag = @section.gsub("manage_", "").upcase
    if params[:entity_id] != "new"

      @doc_entity            = FileDocEntity.new
      @doc_entity.doc_id     = @doc_id
      @doc_entity.file_id    = @file.FileID
      @doc_entity.entity_id  = params[:entity_id]
      @doc_entity.is_active  = 1
      @doc_entity.tag        = tag
      @doc_entity.created_by = current_user.employee_id
      @doc_entity.created_at = Time.now.to_s(:db)
      @doc_entity.updated_by = current_user.employee_id
      @doc_entity.updated_at = Time.now.to_s(:db)

      if @file.file_doc_entities.where("tag = '#{tag}' AND doc_id = #{@doc_id}  AND is_active = 1").last != nil
        @doc_entity.sort_order = @file.file_doc_entities.where("tag = '#{tag}' AND doc_id = #{@doc_id} AND is_active = 1").last.sort_order + 1
      else
        @doc_entity.sort_order = 1
      end

      @doc_entity.save
      @type = @doc_entity.entity.IndCorp

      if @doc_entity.doc_id != 0
        @file.file_doc_fields.where("tag IN ('#{@doc_entity.tag}_NOTARY_VESTING', '#{@doc_entity.tag}_NOTARY_DATE', '#{@doc_entity.tag}_NOTARY_STATE', '#{@doc_entity.tag}_NOTARY_COUNTY') AND is_active = 0 AND doc_id = #{@doc_entity.doc_id} ").each do |field|
          field.is_active  = 1
          field.updated_by = current_user.employee_id
          field.updated_at = Time.now.to_s(:db)
          field.save
        end
      end

      if @doc_entity.tag == 'GRANTOR' && @doc_id == 0
        field = @file.file_doc_fields.where("doc_id = 0 AND is_active = 1 AND tag = 'GRANTOR_TAX_ID' ").first
        if field != nil
          if field == "" && @doc_entity.entity.TaxID != nil && @doc_entity.entity.TaxID != ""
            field.value = @doc_entity.entity.TaxID
            field.updated_by = current_user.employee_id
            field.updated_at = Time.now.to_s(:db)
            field.save
          elsif @doc_entity.entity.TaxID != nil && @doc_entity.entity.TaxID != ""
            field.value += ", #{@doc_entity.entity.TaxID}"
            field.updated_by = current_user.employee_id
            field.updated_at = Time.now.to_s(:db)
            field.save
          end
        else
          field            = FileDocField.new
          field.doc_id     = 0
          field.file_id    = @file.FileID
          field.tag        = "GRANTOR_TAX_ID"
          field.value      = @doc_entity.entity.TaxID || ""
          field.created_by = current_user.employee_id
          field.updated_by = current_user.employee_id
          field.created_at = Time.now.to_s(:db)
          field.updated_at = Time.now.to_s(:db)
          field.is_active  = 1
          field.save
        end
      end

      if @doc_entity.rolodex_signature_id == nil && @doc_entity.entity.rolodex_signatures.first == nil
        entity = @doc_entity.entity

        signature = RolodexSignature.new
        signature.entity_id = entity.EntityID
        signature.description = "Primary"
        signature.created_by = current_user.employee_id
        signature.created_at = Time.now.to_s(:db)
        signature.updated_by = current_user.employee_id
        signature.updated_at = Time.now.to_s(:db)
        signature.save

        @doc_entity.rolodex_signature_id = signature.id
        @doc_entity.save

        signature_primary = RolodexSignatureEntity.new
        entity.name != nil ? signature_primary.name = entity.name : signature_primary.name = ""
        signature_primary.rolodex_signature_id = signature.id
        signature_primary.rolodex_signature_entity_type_id = RolodexSignatureEntityType.where("name = '#{entity.IndCorp}' ").first.id rescue nil
        signature_primary.entity_id = entity.EntityID
        signature_primary.sort_order = 0
        signature_primary.created_at = Time.now.to_s(:db)
        signature_primary.updated_at = Time.now.to_s(:db)
        signature_primary.parent_id = 0

        if entity.IndCorp == "Individual"
          signature_primary.relationship = "signature"
        else
          signature_primary.relationship = "parent"
        end

        signature_primary.save
      elsif @doc_entity.rolodex_signature_id == nil && @doc_entity.entity.rolodex_signatures.first != nil
        @doc_entity.rolodex_signature_id = @doc_entity.entity.rolodex_signatures.first.id
        @doc_entity.save
      end

      # Updates the appropriate notary field with changes to entities and signatures
      update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)

      respond_to do |format|
        format.js { render 'insert_entity' }
      end
    else
      @doc_id = 0 if @doc_id == nil
      render js: "addToQueue('search_entities', 'index/show_overlay?overlay=File Entities&id=#{@file.ID}&form=doc&doc_id=#{@doc_id}&section=#{@section}');"
    end
  end

  def remove_entity
    @doc_entity = FileDocEntity.find params[:id]
    @file       = Index.where("FileID = #{@doc_entity.file_id}").first

    @doc_entity.file_doc_entity_signatures.each do |i|
      i.is_active  = 0
      i.updated_by = current_user.employee_id
      i.updated_at = Time.now.to_s(:db)
      i.save
    end

    @file.file_doc_entities.where("sort_order > #{@doc_entity.sort_order} AND doc_id = #{@doc_entity.doc_id} AND is_active = 1").each do |i|
      i.sort_order = i.sort_order - 1
      i.updated_by = current_user.employee_id
      i.updated_at = Time.now.to_s(:db)
      i.save
    end

    tags = ["NOTARY_VESTING", "NOTARY_DATE", "NOTARY_COUNTY", "NOTARY_STATE"]

    tags.each do |tag|
      @file.file_doc_fields.where("is_active = 1 AND tag LIKE '%_#{tag}_#{@doc_entity.id}%' ").each do |field|
        field.is_active  = 0
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end
    end

    field = @file.file_doc_fields.where("is_active = 1 AND doc_id = 0 AND tag = 'GRANTOR_TAX_ID' ").first
    if field != nil
      value = field.value || ""
      value = value.to_s.gsub(", #{@doc_entity.entity.TaxID}", "")
      value = value.to_s.gsub("#{@doc_entity.entity.TaxID}", "")
      field.value = value
      field.updated_by = current_user.employee_id
      field.updated_at = Time.now.to_s(:db)
      field.save
    end

    @doc_entity.is_active  = 0
    @doc_entity.updated_by = current_user.employee_id
    @doc_entity.updated_at = Time.now.to_s(:db)
    @doc_entity.save

    count = @file.file_doc_entities.where("doc_id = #{@doc_entity.doc_id} AND is_active = 1").count
    if count == 0
      @file.file_doc_fields.where("doc_id = #{@doc_entity.doc_id} AND tag LIKE '%NOTARY%' AND is_active = 1 ").each do|field|
        field.is_active  = 0
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end
    end

    entities = @file.file_doc_entities.where("doc_id = #{@doc_entity.doc_id} AND is_active = 1 AND tag = '#{@doc_entity.tag}'")
    if entities.count == 1
      entity = entities.first
      @file.file_doc_fields.where("doc_id = #{entity.doc_id} AND tag LIKE '#{entity.tag}_NOTARY%_#{entity.id}' AND is_active = 1 ").each do|field|
        field.is_active  = 0
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end
    end

    # Updates the appropriate notary field with changes to entities and signatures
    @remove_entity = @doc_entity
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)

    if @doc_entity.doc_id == 0

      respond_to do |format|
        format.js { render 'update_notary_vesting' }
      end
    else
      respond_to do |format|
        @doc = Doc.find @doc_entity.doc_id
        format.js { render 'signature_preview' }
      end
    end
  end

  def remove_signature
    @doc_signature            = FileDocEntitySignature.find params[:id]
    @doc_signature.is_active  = 0
    @doc_signature.updated_by = current_user.employee_id
    @doc_signature.updated_at = Time.now.to_s(:db)
    @doc_signature.save

    @doc_entity = FileDocEntity.find(@doc_signature.doc_entity_id)
    @file = Index.where("FileID = #{@doc_entity.file_id}").first

    @doc_entity.file_doc_entity_signatures.where("sort_order > #{@doc_signature.sort_order} AND is_active = -1").each do |i|
      i.sort_order = i.sort_order - 1
      i.updated_by = current_user.employee_id
      i.updated_at = Time.now.to_s(:db)
      i.save
    end

    @file.file_doc_fields.where("is_active = 1 AND tag LIKE '%_NOTARY_%_#{@doc_signature.id}' AND tag NOT LIKE  '%_NOTARY_%_#{@doc_signature.id}_' ").each do |field|
      field.is_active  = 0
      field.updated_by = current_user.employee_id
      field.updated_at = Time.now.to_s(:db)
      field.save
    end

    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)

    if @doc_entity.doc_id == 0

      respond_to do |format|
        format.js { render 'update_notary_vesting' }
      end
    else
      respond_to do |format|
        @doc = Doc.find @doc_entity.doc_id
        format.js { render 'signature_preview' }
      end
    end
  end

  def toggle_split_notary
    type = params[:type]
    doc_id = params[:doc_id].to_i rescue 0
    split_id = params[:id]

    if type == "entity"
      @doc_entity = FileDocEntity.find params[:id]
    elsif type == "tree_signature"
      @doc_entity = FileDocEntity.find params[:doc_entity]
    end

    perform_toggle(type, doc_id, split_id, @doc_entity)

    # Updates the appropriate notary field with changes to entities and signatures
    update_notary(@doc_entity.file_id, @doc_entity.tag, @doc_entity.doc_id)

    if @doc_entity.doc_id == 0

      respond_to do |format|
        format.js { render 'update_notary_vesting' }
      end
    else
      respond_to do |format|
        @doc = Doc.find @doc_entity.doc_id
        format.js { render 'signature_preview' }
      end
    end
  end

  def format_signature
    @doc      = Doc.find params[:id]
    @template = @doc.template_text
    @file     = Index.where("FileID = #{@doc.file_id}").first
    @fields   = @file.file_doc_fields
    block     = "#{@doc.doc_signature_type.name.split("_")[0]}_#{params[:block]}"

    @signature = DocSignatureType.where("name = '#{block}' ").first

    @doc.doc_signature_type_id = @signature.id
    @doc.updated_at            = Time.now.to_s(:db)
    @doc.updated_by            = current_user.employee_id
    @doc.save

    respond_to do |format|
      format.js { render 'show_doc' }
    end
  end

  def show_doc
    @doc      = Doc.find(params[:id])
    @template = @doc.template_text
    @file     = Index.where("FileID = #{@doc.file_id}").first
    @fields   = @file.file_doc_fields

    # if @doc.hud_id.nil? == false
    #   schedule_a_old = @file.property_reports.last
    #   hud = @doc.hud
    #   if schedule_a_old.nil? == false && ( (hud.last_viewed_date != nil && schedule_a_old.DummyTime > hud.last_viewed_date) || hud.last_viewed_date == nil )
    #     @refresh_file_info = true
    #     case hud.hud_type
    #     when"standard"
    #       line                 = hud.hud_lines.where(:number => 101).first
    #       line.borrower_amount = schedule_a_old.Policy1Amount || 0
    #       line.save

    #       line                 = hud.hud_lines.where(:number => 202).first
    #       line.borrower_amount = schedule_a_old.Policy2Amount || 0
    #       line.save

    #       hud.initial_loan_amount = schedule_a_old.Policy2Amount || 0
    #       hud.save

    #       line               = hud.hud_lines.where(:number => 401).first
    #       line.seller_amount = schedule_a_old.Policy1Amount || 0
    #       line.save

    #       line        = hud.hud_lines.where(:number => 700).first
    #       line.amount = schedule_a_old.Policy1Amount || 0
    #       line.save

    #       line               = hud.hud_lines.where(:number => 1102).first
    #       if line.updated_at < schedule_a_old.DummyTime || (line.amount == nil && line.seller_amount == nil)
    #         settlement_costs   = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
    #         line.seller_amount = settlement_costs if @file.TransactionDescription1 != "Refinance" && @file.TransactionDescription1 != "Construction Loan"
    #         line.amount        = settlement_costs
    #         line.save
    #       end

    #       line         = hud.hud_lines.where(:number => 1103).first
    #       line.borrower_amount  =  schedule_a_old.OwnerPremiumAmt
    #       line.save

    #       line         = hud.hud_lines.where(:number => 1104).first
    #       line.amount  = schedule_a_old.AltaPremiumAmt
    #       line.description = "#{schedule_a_old.Endorsements}"
    #       line.endorsement_amount = schedule_a_old.EndorsementAmt
    #       line.save

    #       # Policy 1 is the Sales Price
    #       line        = hud.hud_lines.where(:number => 1106).first
    #       line.amount = schedule_a_old.Policy1Amount.nil? ? 0 : schedule_a_old.Policy1Amount
    #       line.save

    #       # Policy 2 is the Loan Amount
    #       line        = hud.hud_lines.where(:number => 1105).first
    #       line.amount = schedule_a_old.Policy2Amount.nil? ? 0 : schedule_a_old.Policy2Amount
    #       line.save
    #     when "in-house"
    #       # Sales Price
    #       line               = hud.hud_lines.where(:number => 3000).first
    #       line.charges = schedule_a_old.Policy1Amount || 0
    #       line.save

    #       # Closing Fee
    #       line               = hud.hud_lines.where(:number => 3006).first
    #       if line.updated_at < schedule_a_old.DummyTime
    #         settlement_costs   = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
    #         line.charges = settlement_costs
    #         line.save
    #       end

    #       line               = hud.hud_lines.where(:number => 4006).first
    #       if line.updated_at < schedule_a_old.DummyTime
    #         settlement_costs   = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
    #         line.charges = settlement_costs
    #         line.save
    #       end

    #       # Policy Amounts
    #       line         = hud.hud_lines.where(:number => 4004).first
    #       line.charges  =  schedule_a_old.OwnerPremiumAmt.to_f
    #       line.save

    #       line         = hud.hud_lines.where(:number => 3004).first
    #       line.charges  = schedule_a_old.AltaPremiumAmt
    #       line.save
    #     when "loan-in-house"
    #       # Closing Fee
    #       line               = hud.hud_lines.where(:number => 5006).first
    #       if line.updated_at < schedule_a_old.DummyTime
    #         settlement_costs   = schedule_a_old.Policy2Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy2Amount) : 295.00)
    #         line.charges = settlement_costs
    #         line.save
    #       end

    #       # Policy Amounts
    #       line         = hud.hud_lines.where(:number => 5004).first
    #       line.charges  = schedule_a_old.AltaPremiumAmt
    #       line.save
    #     end
    #     hud.update_hud_invoice
    #   end

    #   hud.last_viewed_date = Time.now.to_s(:db)
    #   hud.save
    # end
  end

  def show_editor
    @doc = Doc.find params[:id]
  end

  def show_lookup_options
    case params[:option]
    when "1"
      @type   = "doc"
      @option = params[:option]
    when "2"
      @type   = "group"
      @option = params[:option]
    when "3"
      @type   = "prior"
      @option = params[:option]
    end
    @file_id = params[:file_id]
  end

  def display_search_results
    if params[:state] != nil && params[:state] != "All"
      state = " AND (state = '#{params[:state]}' OR state IS NULL OR state = '' )"
    else
      state = ""
    end


    case params[:type]
    when "doc"
      @templates = DocTemplate.where("(description LIKE '%#{params[:search]}%' OR short_name LIKE '%#{params[:search]}%') AND is_active = 1 #{state} ").order("description ASC")
      @file_id   = params[:file_id]
    when "group"
      if params[:search] != ""
        search = " AND name LIKE '%#{params[:search]}%' "
      else
        search = ""
      end

      @groups  = DocGroup.where("is_active = -1 #{search} #{state}")
      # @group_templates = []

      # if @group != nil
      #   @group.doc_group_templates.each do |template|
      #     @group_templates << template
      #   end
      # end

      @file_id = params[:file_id]
    when "prior"
    end
  end

  def show_send
    @file = Index.find params[:file_id]
    @docs = []
    params[:docs].each do |i|
      doc = Doc.find i
      @docs.push doc
    end
  end

  def send_docs
    render nothing: true
  end

  def destroy
    @file = Index.where("FileID = #{params[:file_id]}").first
    sent_for_funding = Index.where("FileID = #{params[:file_id]}").first.SentForFunding rescue nil
    docs = params[:docs]
    invoices = {}

    if docs != "" && docs != nil
      docs.each do |d|
        doc           = Doc.find(d)


        if doc.invoice != nil
          invoices[doc.id] = doc if invoices[doc.id] == nil
        else
          if sent_for_funding != nil && doc.filing_1099_id != nil
            @save_1099 = true
          elsif doc.filing_1099_id != nil
            filing = Filing1099.find doc.filing_1099_id
            filing.destroy
            doc.destroy
          else
            if doc.doc_template.short_name == "1099" && @file.docs.where("doc_template_id = #{doc.doc_template_id} AND doc_entity_id = #{doc.doc_entity_id} AND is_active != 0 AND id != #{doc.id}").first.nil?
              @file.file_doc_fields.where("tag LIKE '1099%#{doc.doc_entity_id}'").each do |field|
                field.value = ""
                field.is_active = 0
                field.save
              end
            end

            doc.destroy
          end
        end
      end
    end

    @doc_list = @file.docs.find(:all, conditions: ["docs.is_active = -1"], include: [:doc_template], order: ["doc_templates.short_name ASC"])

    if @doc_list.size > 0
      @template        = @file.docs.order("updated_at DESC").first.template_text
      @file_doc_fields = @file.file_doc_fields
      @fields          = generate_doc_fields(@file.docs)
      @field_array     = generate_doc_fields(@file.docs)
    end

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def doc_list
    @file = Index.find params[:file_id]
    @doc_list = @file.docs.find(:all, conditions: ["docs.is_active = -1"], include: [:doc_template], order: ["doc_templates.short_name ASC"])
    @doc = @doc_list.first

    @file.file_doc_entities.each do |i|
      i.file_doc_entity_signatures.where("name IS NULL AND signature IS NULL AND is_active = 0").each do |j|
        j.destroy
      end
    end

    if @file.docs.size > 0
      @template        = @doc.template_text if @doc != nil
      @file_doc_fields = @file.file_doc_fields
      @fields          = generate_doc_fields(@file.docs)
      @field_array     = generate_doc_fields(@file.docs)
    end
  end

  def save_template
    @doc = Doc.find params[:id]
    @history_doc = DocHistory.new
    @file        = Index.where("FileID = #{@doc.file_id}").first
    @doc_list = @file.docs.find(:all, conditions: ["docs.is_active = -1"], include: [:doc_template], order: ["doc_templates.short_name ASC"])

    if @doc.template_text.to_s != params[:text]
      @history_doc.doc_id               = @doc.id
      @history_doc.doc_template_id      = @doc.doc_template_id
      @history_doc.doc_template_version = @doc.doc_template_version
      @history_doc.template_text        = @doc.template_text
      @history_doc.created_by           = @doc.updated_by
      @history_doc.created_at           = @doc.updated_at
      @history_doc.save
      @doc.template_text        = params[:text]
      @doc.updated_by           = current_user.employee_id
      @doc.updated_at           = Time.now.to_s(:db)
      @doc.save
    end

    if @doc_list.size > 0
     @template        = @file.docs.first.template_text
     @file_doc_fields = @file.file_doc_fields
     @field_array     = generate_doc_fields(@file.docs)
    end

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def save
    @file    = Index.where("FileID = #{params[:file_id]}").first
    @docs    = params[:docs]
    @content = ""
    @html    = ""
    @print   = "print"
    @n       = 0
    @pre_hud = params[:pre_hud]

    if params[:side] == "Buyer"
      @show = "Buyer"
      @side = " .print_seller{ visibility: hidden; } "
    elsif params[:side] == "Seller"
      @show = "Seller"
      @side = " .print_buyer{ visibility: hidden; } "
    else
      @show = ""
      @side = ""
    end

    @break = "<div style='page-break-after:always;'></div>"

    @javascript = "<script type='text/javascript'>window.print();</script>"

    respond_to do |format|
      format.js
    end
  end

  def print
    @file    = Index.where("FileID = #{params[:file_id]}").first
    @docs    = params[:docs]
    @content = ""
    @html    = ""
    @print   = "print"
    @n       = 0

    if params[:side] == "Buyer"
      @show = "Buyer"
      @side = " .print_seller{ visibility: hidden; } "
    elsif params[:side] == "Seller"
      @show = "Seller"
      @side = " .print_buyer{ visibility: hidden; } "
    else
      @show = ""
      @side = ""
    end

    @break = "<div style='page-break-after:always;'></div>"

    @javascript = "<script type='text/javascript'>window.print();</script>"

    respond_to do |format|
      format.js
    end
  end

  def send_doc
    employee_id = params[:employee_id]
    company_id  = params[:company_id]
    file_id     = params[:file_id]
    save_file   = true if params[:save_file]
    content     = params[:content]
    count       = 1
    if content.kind_of?(Array)
      tmp_file = random_string + ".pdf"
      tmp_path = File.expand_path(tmp_file, Rails.root + "tmp/docs/")
      list     = ""
      content.each do |c|
        list = " " + list + " " + File.expand_path(c, Rails.root + "tmp/docs/")
      end
      system("pdftk #{list} cat output #{tmp_path}")
      content.each do |c|
        file = File.expand_path(c, Rails.root + "tmp/docs/")
        File.delete(file)
      end
      if save_file
        FileUtils.mkdir_p(Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}"))
        if File.file?(Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs.pdf"))
          until File.file?(Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs-#{count}.pdf")) == false
            count += 1
          end
          FileUtils.mv(tmp_path, Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs-#{count}.pdf"))
        else
          FileUtils.mv(tmp_path, Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs.pdf"))
        end
        render nothing: true
      else
        send_file(tmp_path, filename: "doc.pdf", disposition: "inline")
      end
    else
      filename = content
      path     = File.expand_path(filename, Rails.root.join("tmp/docs/"))
      if save_file
        FileUtils.mkdir_p(Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}"))
        if File.file?(Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs.pdf"))
          until File.file?(Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs-#{count}.pdf")) == false
            count += 1
          end
          FileUtils.mv(path, Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs-#{count}.pdf"))
        else
          FileUtils.mv(path, Rails.root.join("tmp/index_dnd/#{employee_id}/#{company_id}/#{file_id}/docs.pdf"))
        end
        render nothing: true
      else
        send_file(path, filename: "doc.pdf", disposition: "inline")
      end
    end
  end

  def reset_fields
    time  = Time.now.to_s(:db)
    doc   = Doc.find params[:id]
    @file = Index.where("FileID = #{doc.file_id}").first
    entities = []

    @file.file_doc_entities.where("doc_id = 0 and is_active = 1").each do |e|
      entities << e
      e.is_active = 0
      e.save
    end

    @file.file_doc_fields.where("doc_id = 0").each do |i|
      i.destroy
    end

    initialize_standard_fields

    entities.each do |i|
      i.file_doc_entity_signatures.each do |s|
        s.destroy
      end

      entity = @file.file_doc_entities.where("entity_id = #{i.entity_id} and is_active = 1").first

      unless entity == nil
        @file.docs.where("doc_entity_id = #{i.id}").each do |d|
          d.doc_entity_id = entity.id
          d.save
          initialize_doc_fields(d)

          # d.file_doc_fields.each do |f|
          #   f.tag = "#{f.tag.split('_')[0..-2].join('_')}_#{entity.id}"
          #   f.save
          # end
        end
      end

      i.destroy
    end

    entity_docs = @file.docs.where("doc_entity_id IS NOT NULL")
    entities = []
    @file.file_doc_entities.where("doc_id = 0 and is_active = 1").each do |e|
      entities << e.id
    end

    entity_docs.each do |d|
      unless entities.include?(d.doc_entity_id)
        d.is_active = 0
        d.updated_at  = Time.now.to_s(:db)
        d.updated_by  = current_user.employee_id
        d.save
      end
    end

    @doc_list = @file.docs.find(:all, conditions: ["docs.is_active = -1"], include: [:doc_template], order: ["doc_templates.short_name ASC"])

    other_standard = ["ACK", "TPA"]
    @doc_list.each do |doc|
      unless !other_standard.include?(doc.doc_template.short_name)
        initialize_other_standard_doc_fields(doc)
      end
    end

    if @doc_list.size > 0
      @template        = @file.docs.order("updated_at DESC").first.template_text
      @file_doc_fields = @file.file_doc_fields
      @fields          = generate_doc_fields(@file.docs)
      @field_array     = generate_doc_fields(@file.docs)
    end

    respond_to do |format|
      format.js { render 'doc_list' }
    end
  end

  def create_hud(doc, type = "standard")
    hud         = Hud.new
    hud.file_id = @file.FileID
    # Create HUD Lines
    hud.setup(type)
    hud.save
    # hud.invoice_id = create_invoice_from_hud(hud, type) # Creates a new doc and invoice
    hud.save

    hud.file_number = @file.DisplayFileID
    hud.hud_type = type
    hud.borrower_name     = @file.file_doc_fields.where("tag = 'GRANTEE_NAMES' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_address1 = @file.file_doc_fields.where("tag = 'GRANTEE_ADDRESS_1' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_address2 = @file.file_doc_fields.where("tag = 'GRANTEE_ADDRESS_2' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_city     = @file.file_doc_fields.where("tag = 'GRANTEE_CITY' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_state    = @file.file_doc_fields.where("tag = 'GRANTEE_STATE' AND doc_id = 0 AND is_active = 1").first.value
    hud.borrower_zip      = @file.file_doc_fields.where("tag = 'GRANTEE_ZIP' AND doc_id = 0 AND is_active = 1").first.value

    if type != "loan-in-house"
      hud.seller_name     = @file.file_doc_fields.where("tag = 'GRANTOR_NAMES' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_address1 = @file.file_doc_fields.where("tag = 'GRANTOR_ADDRESS_1' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_address2 = @file.file_doc_fields.where("tag = 'GRANTOR_ADDRESS_2' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_city     = @file.file_doc_fields.where("tag = 'GRANTOR_CITY' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_state    = @file.file_doc_fields.where("tag = 'GRANTOR_STATE' AND doc_id = 0 AND is_active = 1").first.value
      hud.seller_zip      = @file.file_doc_fields.where("tag = 'GRANTOR_ZIP' AND doc_id = 0 AND is_active = 1").first.value
    end

    lender = @file.file_entities.where("Position = 3").last
    if  lender != nil
      lender              = lender.entity
      hud.lender_name     = lender.name
      hud.lender_address1 = "#{lender.address[0]} #{lender.address[1]}"
      # hud.lender_address2 = lender.address[1]
      hud.lender_city     = lender.address[2]
      hud.lender_state    = lender.address[3]
      hud.lender_zip      = lender.address[4]

      list = ["NAME", "ADDRESS_1", "ADDRESS_2", "CITY", "STATE", "ZIP"]

      list.each do |tag|
        field = @file.file_doc_fields.where("doc_id = 0 AND tag = 'LENDER_#{tag}' AND is_active = 1").first
        if field == nil
          field = FileDocField.new
          field.tag = "LENDER_#{tag}"
          field.file_id = @file.FileID
          field.doc_id = 0
          field.is_active = 1
          field.created_by = current_user.employee_id
          field.created_at = Time.now.to_s(:db)
        end

        field.updated_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)

        case tag
        when "NAME"
          field.value = hud.lender_name
        when "ADDRESS_1"
          field.value = lender.address[0]
        when "ADDRESS_2"
          field.value = lender.address[1]
        when "CITY"
          field.value = hud.lender_city
        when "STATE"
          field.value = hud.lender_state
        when "ZIP"
          field.value = hud.lender_zip
        end

        field.save
      end

      # Payee in 800 Section
      fill_lines = [801, 5017, 5018, 5019, 5020]
      fill_lines.each do |l|
        line = hud.hud_lines.where(:number => l).first
        if line
          line.payee_name = lender.name
          line.payee_id   = lender.EntityID
          line.save
        end
      end
    end

    agent    = ""
    location = ""
    @file.file_employees.where("Position like 'Closer%' ").each do |closer|
      if agent == ""
        agent    = "#{closer.employee.FullName}"
        location = "#{closer.employee.closer.office.OfficeAddress1} #{closer.employee.closer.office.OfficeAddress2}, #{closer.employee.closer.office.OfficeCity}, #{closer.employee.closer.office.OfficeState} #{closer.employee.closer.office.OfficeZip}" rescue ""
      else
        agent += " and #{closer.employee.FullName}"
      end
    end
    hud.settlement_agent   = agent if agent != ""
    hud.settlement_date    = @file.COEDate
    hud.settlment_location = location if location != ""
    hud.loan_number        = @file.LoanNum
    schedule_a_old = @file.property_reports.last

    if type == "standard"
      # Set up Totals so we can disburse to Buyer and Seller as neccessary
      sides = {"GRANTOR" => 603, "GRANTEE" => 303}
      sides.each do |key, value|
        entity = @file.file_doc_entities.where("tag = '#{key}'").first
        if entity
          line            = hud.hud_lines.where(:number => value).first
          line.payee_name = @file.file_doc_fields.where("tag = '#{key}_NAMES' AND doc_id = 0 AND is_active != 0").first.value
          line.payee_id   = entity.entity_id
          line.save
        end
      end

      if @file.file_doc_fields.where("tag='COMPANY_PHONE' AND doc_id=0 AND is_active != 0").first == nil
        field = FileDocField.new
        field.doc_id = 0
        field.file_id = @file.FileID
        field.tag = "COMPANY_PHONE"
        field.value = @file.company.CompanyPhone rescue ""
        field.is_active = 1
        field.created_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end

      if @file.file_doc_fields.where("tag='SETTLEMENT_PHONE' AND doc_id=0 AND is_active != 0").first == nil
        field = FileDocField.new
        field.doc_id = 0
        field.file_id = @file.FileID
        field.tag = "SETTLEMENT_PHONE"
        field.value = number_to_phone(@file.closer.office.OfficePhone, area_code: true) rescue ""
        field.is_active = 1
        field.created_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end

      # Import Company for 1100 Section
      company    = Company.find @file.Company
      fill_lines = [1101, 1102, 1103, 1104, 1105, 1106, 1201, 1202]
      fill_lines.each do |l|
        line            = hud.hud_lines.where(:number => l).first
        if ( (l == 1103 && @file.SellerSide == 0) || (l == 1104 && @file.BuyerSide == 0) ) && (@file.SellerSide != 0 || @file.BuyerSide != 0)
          line.payee_name = @file.SplitTitle if @file.SplitTitle != ""
        else
          line.payee_name = company.CompanyName
          line.payee_id   = company.CompanyID
        end

        case l
        when 1102
          line.invoice_category = "ClosingFee"
        when 1103
          line.invoice_category = "OwnerPol"
        when 1104
          line.invoice_category = "LenderPol/Endorsements"
        when 1201
          line.invoice_category = "RecFee"
        when 1202
          line.invoice_category = "RecFee"
        end

        line.save
      end

      # County Information
      case company.DefaultCounty
      when 1
        id = 177906
      when 2
        id = 186270
      when 4
        id = 275601
      when 5
        id = 364122
      end

      if id != nil
        entity = Entity.find id
        fill_lines = [106, 107, 108, 510, 511, 512, 1203, 1204, 1205]
        year = Time.now.strftime("%Y")

        fill_lines.each do |l|
          line            = hud.hud_lines.where(:number => l).first
          line.payee_name = entity.name
          line.payee_id   = entity.EntityID
          line.save
        end
      end

      line = hud.hud_lines.where('number = 901').first
      line.start_date = @file.COEDate
      if line.start_date != nil && line.start_date != ""
        date = line.start_date.to_s.split("-")
        date[1] = (date[1].to_i + 1).to_s
        # If the month spills over 12, reset it to 1 and increment to next year
        if date[1] == "13"
          date[1] = "01"
          date[0] = (date[0].to_i + 1).to_s
        end
        date[2] = "01"
        date = date.join("-")
        line.end_date = date
      end
      line.save
      line = nil

      earnest_money = Receipt.where("FileID = #{@file.FileID} AND EarnestMoney != 0").first
      if earnest_money != nil
        line            = hud.hud_lines.where(:number => 704).first
        line.payee_name = company.CompanyName
        line.payee_id   = company.CompanyID
        line.amount     = earnest_money.ReceiptAmount.to_f
        line.save
      end

      # Realtor Brokerage for commission lines
      realtors = []
      realtors << @file.file_entities.where("Position" => 12).first
      realtors << @file.file_entities.where("Position" => 13).first
      @file.file_entities.where("Position" => 14).each do |brokerage|
        realtors << brokerage
      end
      n = 0
      realtors.each do |r|
        if r != nil
          n += 1
          if n == 1
            line            = hud.hud_lines.where(:number => 701).first
            line.payee_name = r.entity.name
            line.payee_id   = r.EntityID
            line.save

            if r.Position == 12 && earnest_money == nil
              line            = hud.hud_lines.where(:number => 704).first
              line.payee_name = r.entity.name
              line.payee_id   = r.EntityID
              line.save
            end
          elsif n == 2
            line            = hud.hud_lines.where(:number => 702).first
            line.payee_name = r.entity.name
            line.payee_id   = r.EntityID
            line.save
            break
          end
        end
      end

      if schedule_a_old.nil?
        line                 = hud.hud_lines.where(:number => 101).first
        line.borrower_amount = @file.SalesPrice
        line.save

        line                 = hud.hud_lines.where(:number => 202).first
        line.borrower_amount = @file.LoanAmount
        line.save

        hud.initial_loan_amount = @file.LoanAmount

        line               = hud.hud_lines.where(:number => 401).first
        line.seller_amount = @file.SalesPrice
        line.save

        line        = hud.hud_lines.where(:number => 700).first
        line.amount = @file.SalesPrice
        line.save

        settlement_costs   = 295.00
        line               = hud.hud_lines.where(:number => 1102).first
        line.seller_amount = settlement_costs unless Index.loan_transactions.include?(@file.TransactionDescription1)
        line.amount        = settlement_costs
        line.save

        line        = hud.hud_lines.where(:number => 1105).first
        line.amount = @file.LoanAmount
        line.save

        line        = hud.hud_lines.where(:number => 1106).first
        line.amount = @file.SalesPrice
        line.save

        line                    = hud.hud_lines.where(:number => 1104).first
        line.invoice_category   = "Endorsements"
        line.payee_name         = @file.company.CompanyName
        line.save
      else
        line                 = hud.hud_lines.where(:number => 101).first
        line.borrower_amount = schedule_a_old.Policy1Amount || 0
        line.save

        line                 = hud.hud_lines.where(:number => 202).first
        line.borrower_amount = schedule_a_old.Policy2Amount || 0
        line.save

        hud.initial_loan_amount = schedule_a_old.Policy2Amount || 0

        line               = hud.hud_lines.where(:number => 401).first
        line.seller_amount = schedule_a_old.Policy1Amount || 0
        line.save

        line        = hud.hud_lines.where(:number => 700).first
        line.amount = schedule_a_old.Policy1Amount || 0
        line.save

        settlement_costs   = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
        line               = hud.hud_lines.where(:number => 1102).first
        line.seller_amount = settlement_costs unless Index.loan_transactions.include?(@file.TransactionDescription1)
        line.amount        = settlement_costs
        line.save

        line         = hud.hud_lines.where(:number => 1103).first
        line.borrower_amount  =  schedule_a_old.OwnerPremiumAmt
        line.save

        line         = hud.hud_lines.where(:number => 1104).first
        line.amount  =  schedule_a_old.AltaPremiumAmt
        line.save

        # Policy 1 is the Sales Price
        line        = hud.hud_lines.where(:number => 1105).first
        line.amount = schedule_a_old.Policy1Amount.nil? ? 0 : schedule_a_old.Policy1Amount
        line.save

        # Policy 2 is the Loan Amount
        line        = hud.hud_lines.where(:number => 1106).first
        line.amount = schedule_a_old.Policy2Amount.nil? ? 0 : schedule_a_old.Policy2Amount
        line.save

        line                    = hud.hud_lines.where(:number => 1104).first
        line.description        = "#{schedule_a_old.Endorsements}"
        line.endorsement_amount = schedule_a_old.EndorsementAmt
        line.invoice_category   = "Endorsements"
        line.payee_name         = @file.company.CompanyName
        line.save
      end

    elsif type == "in-house"
      line         = hud.hud_lines.where(:number => 3000).first
      line.charges = schedule_a_old.nil? ? @file.SalesPrice : schedule_a_old.Policy1Amount.to_f
      line.save

      line         = hud.hud_lines.where(:number => 4000).first
      line.credits = schedule_a_old.nil? ? @file.SalesPrice : schedule_a_old.Policy1Amount.to_f
      line.save

      closing_date = @file.file_doc_fields.where("tag = 'CLOSING_DATE' and doc_id = 0").first.value

      if closing_date != ""
        month = closing_date.split("/")[0] rescue Time.now.strftime("%m")
        day = closing_date.split("/")[1] rescue Time.now.strftime("%d")
        year = closing_date.split("/")[2] rescue Time.now.strftime("%Y")

        line = hud.hud_lines.where(:number => 4012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = "#{year}-#{month}-#{day} 00:00:00" # @file.Recorded unless @file.Recorded.nil?
        line.save

        line = hud.hud_lines.where(:number => 3012).first
        line.start_date = "#{year}-#{month}-#{day.to_i} 00:00:00" # @file.Recorded + 1.day unless @file.Recorded.nil?
        line.start_date += 1.day rescue nil
        line.end_date   = "#{Time.now.strftime("%Y").to_i + 1}-01-01 00:00:00"
        line.save
      else
        line = hud.hud_lines.where(:number => 4012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = @file.COEDate
        line.save

        line = hud.hud_lines.where(:number => 3012).first
        line.start_date = @file.COEDate # @file.Recorded + 1.day unless @file.Recorded.nil?
        line.start_date += 1.day rescue nil
        line.end_date   = "#{Time.now.strftime("%Y").to_i + 1}-01-01 00:00:00"
        line.save
      end

      # Set up Totals so we can disburse to Buyer and Seller as neccessary
      sides = {"GRANTOR" => 4097, "GRANTEE" => 3097}
      sides.each do |key, value|
        entity = @file.file_doc_entities.where("tag = '#{key}'").first
        if entity
          line            = hud.hud_lines.where(:number => value).first
          line.payee_name = @file.file_doc_fields.where("tag = '#{key}_VESTING' AND doc_id = 0").first.value
          line.payee_id   = entity.entity_id
          line.save
        end
      end

      # Import Company for 1100 Section
      company = Company.find @file.Company
      fill_lines = [3004, 3005, 3006, 3007, 3008, 3009, 4004, 4005, 4006, 4007, 4008, 4009]
      fill_lines.each do |l|
        line = hud.hud_lines.where(:number => l).first
        line.payee_name = company.CompanyName
        line.payee_id = company.CompanyID

        case l
        when 3004
          line.invoice_category = "LenderPol"
          if schedule_a_old.nil? == false
            alta_prem    = schedule_a_old.AltaPremiumAmt || 0
            endorsements = schedule_a_old.EndorsementAmt || 0
            line.charges  =  alta_prem.to_f + endorsements.to_f
          end
        when 3005
          line.invoice_category = "RecFee"
        when 3006
          line.invoice_category = "ClosingFee"
          if schedule_a_old.nil? == false
            settlement_costs = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
            line.charges = settlement_costs
          else
            line.charges = 295.00
          end
        when 3007
          line.invoice_category = "EscrowCol"
        when 3008
          line.invoice_category = "FedEx"
        when 3009
          line.invoice_category = "DocPrep"
        when 4004
          line.invoice_category = "OwnerPol"
          if schedule_a_old.nil? == false
            line.charges = schedule_a_old.OwnerPremiumAmt.nil? ? 0 : schedule_a_old.OwnerPremiumAmt
          end
        when 4005
          line.invoice_category = "RecFee"
        when 4006
          line.invoice_category = "ClosingFee"
          if schedule_a_old.nil? == false
            settlement_costs = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
            line.charges = settlement_costs
          else
            line.charges = 295.00
          end
        when 4007
          line.invoice_category = "EscrowCol"
        when 4008
          line.invoice_category = "FedEx"
        when 4009
          line.invoice_category = "DocPrep"
        end

        line.save
      end

      earnest_money = Receipt.where("FileID = #{@file.FileID} AND EarnestMoney != 0").first
      if earnest_money != nil
        lines = [4001, 3001]
        lines.each do |number|
          line            = hud.hud_lines.where(:number => number).first
          line.payee_name = company.CompanyName
          line.payee_id   = company.CompanyID
          line.amount     = earnest_money.ReceiptAmount
          line.save
        end
      end

      # Realtor Brokerage for commission lines
      realtors = []
      realtors << @file.file_entities.where("Position" => 12).first
      realtors << @file.file_entities.where("Position" => 13).first
      @file.file_entities.where("Position" => 14).each do |brokerage|
        realtors << brokerage if brokerage != nil
      end

      if realtors.count > 0
        line = hud.hud_lines.where(:number => 4020).first
        line.group      = "ss_commission"
        line.type       = "ss_header_custom"
        line.name       = "COMMISSIONS:"
        line.amount     = @file.SalesPrice
        line.save

        line            = hud.hud_lines.where(:number => 4023).first
        line.type       = "ss_commission_total_custom"
        line.group      = "ss_commission"
        line.save
      end

      i = 0
      j = 0
      while i < 2 && j < realtors.count
        if realtors[j] != nil
          line            = hud.hud_lines.where(:number => 4021 + i).first
          line.payee_name = realtors[j].entity.name
          line.payee_id   = realtors[j].EntityID
          line.percent    = 3
          line.type       = "ss_commission_custom"
          line.group      = "ss_commission"
          line.save
          i += 1

          if realtors[j].Position == 12 && earnest_money == nil
            lines = [4001, 3001]
            lines.each do |number|
              line            = hud.hud_lines.where(:number => number).first
              line.payee_name = realtors[j].entity.name
              line.payee_id   = realtors[j].EntityID
              line.save
            end
          end
        end
        j += 1
      end

      while i < 2
        line            = hud.hud_lines.where(:number => 4021 + i).first
        line.type       = "ss_commission_custom"
        line.group      = "ss_commission"
        line.save
        i += 1
      end

      # County Information
      case company.DefaultCounty
      when 1
        id = 177906
      when 2
        id = 186270
      when 4
        id = 275601
      when 5
        id = 364122
      end

      if id != nil
        entity = Entity.find id
        fill_lines = [3013, 4013]
        fill_lines.each do |l|
          line            = hud.hud_lines.where(:number => l).first
          line.payee_name = entity.name
          line.payee_id   = entity.EntityID
          line.save
        end
      end

      # Set up seller finance if needed.
      if @file.TransactionDescription1 = "Seller Finance"
        line = hud.hud_lines.where("number = 3021").first
        line.type = "ss_normal"
        line.name = "Trust Deed and Note with Sellers"
        line.save

        line = hud.hud_lines.where("number = 4025").first
        line.type = "ss_normal"
        line.name = "Trust Deed and Note with Buyers"
        line.save
      end

    elsif type == "loan-in-house"
      line         = hud.hud_lines.where(:number => 5000).first
      line.credits = schedule_a_old.nil? ? @file.LoanAmount : schedule_a_old.Policy2Amount.to_f
      line.save

      # Set up Totals so we can disburse to Buyer as neccessary
      entity = @file.file_doc_entities.where("tag = 'GRANTEE'").first
      if entity
        line            = hud.hud_lines.where(:number => 5099).first
        line.payee_name = @file.file_doc_fields.where("tag = 'GRANTEE_NAMES' AND doc_id = 0").first.value
        line.payee_id   = entity.entity_id
        line.save
      end

      closing_date = @file.file_doc_fields.where("tag = 'CLOSING_DATE' and doc_id = 0").first.value
      if closing_date != ""
        month = closing_date.split("/")[0] rescue Time.now.strftime("%m")
        day = closing_date.split("/")[1] rescue Time.now.strftime("%d")
        year = closing_date.split("/")[2] rescue Time.now.strftime("%Y")

        line = hud.hud_lines.where(:number => 5012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = "#{year}-#{month}-#{day} 00:00:00" # @file.Recorded unless @file.Recorded.nil?
        line.save
      else
        line = hud.hud_lines.where(:number => 5012).first
        line.start_date = "#{Time.now.strftime("%Y")}-01-01 00:00:00"
        line.end_date   = @file.COEDate
        line.save
      end

      # Import Company for 1100 Section
      company = Company.find @file.Company
      fill_lines = [5004, 5005, 5006, 5007, 5008, 5009]
      fill_lines.each do |l|
        line = hud.hud_lines.where(:number => l).first
        line.payee_name = company.CompanyName
        line.payee_id = company.CompanyID

        case l
        when 5004
          line.invoice_category = "LenderPol"
          if schedule_a_old.nil? == false
            alta_prem    = schedule_a_old.AltaPremiumAmt || 0
            endorsements = schedule_a_old.EndorsementAmt || 0
            line.charges  =  alta_prem.to_f + endorsements.to_f
          end
        when 5005
          line.invoice_category = "RecFee"
        when 5006
          line.invoice_category = "ClosingFee"
          if schedule_a_old.nil? == false
            settlement_costs = schedule_a_old.Policy1Amount.nil? ? 295.00 : (Doc.new.settlement_costs(schedule_a_old.Policy1Amount) > 295.00 ? Doc.new.settlement_costs(schedule_a_old.Policy1Amount) : 295.00)
            line.charges = settlement_costs
          else
            line.charges = 295.00
          end
        when 5007
          line.invoice_category = "EscrowCol"
        when 5008
          line.invoice_category = "FedEx"
        when 5009
          line.invoice_category = "DocPrep"
        end

        line.save
      end

      # County Information
      case company.DefaultCounty
      when 1
        id = 177906
      when 2
        id = 186270
      when 4
        id = 275601
      when 5
        id = 364122
      end

      if id != nil
        entity = Entity.find id
        fill_lines = [5013]
        fill_lines.each do |l|
          line            = hud.hud_lines.where(:number => l).first
          line.payee_name = entity.name
          line.payee_id   = entity.EntityID
          line.save
        end
      end
    end

    address                = @file.file_doc_fields.where("tag = 'PROPERTY_ADDRESS' and is_active = 1 and doc_id = 0").first.value
    if address != ""
      address               = "#{address}"
      city                  = ", #{@file.file_doc_fields.where("tag = 'PROPERTY_CITY' and is_active = 1 and doc_id = 0").first.value}" rescue ""
      state                 = ", #{@file.file_doc_fields.where("tag = 'PROPERTY_STATE' and is_active = 1 and doc_id = 0").first.value}" rescue ""
      zip                   = " #{@file.file_doc_fields.where("tag = 'PROPERTY_ZIP' and is_active = 1 and doc_id = 0").first.value}" rescue ""
      hud.property_location = "#{address}#{city}#{state}#{zip}"
    end


    hud.save


    # Update Mark and Andy when file is sent for funding from new system
    case type
    when "standard"
      name = "HUD"
    when "in-house"
      name = "Inhouse Settlement Statement"
    when "loan-in-house"
      name = "Loan Inhouse Settlement Statement"
    end

    NoticeMailer.notification(current_user, "File ##{@file.DisplayFileID} #{name} Created.", "#{current_user.employee.FullName} has created a #{name} through the new system.", "Mark Meacham", "markm@efusionpro.com").deliver if Rails.env.production?
    NoticeMailer.notification(current_user, "File ##{@file.DisplayFileID} #{name} Created.", "#{current_user.employee.FullName} has created a #{name} through the new system.", "Andrew Bryner", "andy@titlemanagers.com").deliver if Rails.env.production?
    return hud
  end

  private

  def update_1099(doc, field, value)
    filing = Filing1099.find doc.filing_1099_id

    case field.tag
    when "1099_SELLER_NAME_#{doc.doc_entity_id}"
      filing.SellerName5 = value
    when "1099_FORWARDING_#{doc.doc_entity_id}"
      filing.SellerAddress6 = value
    when "1099_CITY_#{doc.doc_entity_id}"
      filing.City7 = value
    when "1099_STATE_#{doc.doc_entity_id}"
      filing.State8 = value
    when "1099_ZIP_#{doc.doc_entity_id}"
      filing.Zip9 = value
    when "1099_TAX_ID_#{doc.doc_entity_id}"
      filing.SSNTaxID10 = value
    when "FULL_PROPERTY_ADDRESS"
      filing.PropertyDescrip11 = value
    when "1099_GROSS_PROCEEDS_#{doc.doc_entity_id}"
      filing.GrossProceeds12 = value.gsub(",", "").to_i
    when "1099_BUYERS_PART_#{doc.doc_entity_id}"
      value == "" ? filing.BuyersPartorREtax15 = "0" : filing.BuyersPartorREtax15 = value
    when "CB_1099_#{doc.doc_entity_id}"
      filing.OtherthanCash13 = value.to_i * -1
    when "CB_1099_REVIEWED_#{doc.doc_entity_id}"
      filing.IsReviewed = value.to_i * -1
      if filing.IsReviewed != 0
        filing.ReviewedDT = field.updated_at
        filing.ReviewedBy = field.updated_by
      else
        filing.ReviewedDT = nil
        filing.ReviewedBy = nil
      end
    when "GRANTOR_SIGNING_DATE"
      filing.ClosingDate14 = datetime_parse(value) rescue nil
    end
    filing.save
  end

  def perform_toggle(type, doc_id, split_id, doc_entity)
    list = ["NOTARY_VESTING", "NOTARY_DATE","NOTARY_COUNTY","NOTARY_STATE"]

    case type
    when "entity"
      id = split_id
      @file = Index.where("FileID = #{doc_entity.file_id}").first
      fields = @file.file_doc_fields.where("is_active = 1 AND doc_id = #{doc_entity.doc_id} AND tag LIKE '%NOTARY_%#{id}' AND tag NOT LIKE '%TREE%' ")
      inactive_fields = @file.file_doc_fields.where("is_active = 0 AND doc_id = #{doc_entity.doc_id} AND tag LIKE '%NOTARY_%#{id}' AND tag NOT LIKE '%TREE%' ")
    when "signature"
      doc_signature = FileDocEntitySignature.find split_id
      #doc_entity = FileDocEntity.find doc_signature.doc_entity_id
      id = "#{doc_entity.id}_#{split_id}"
      @file = Index.where("FileID = #{doc_entity.file_id}").first
      fields = @file.file_doc_fields.where("is_active = 1 AND doc_id = #{doc_entity.doc_id} AND tag LIKE '%NOTARY_%#{id}' AND tag NOT LIKE '%TREE%' ")
      inactive_fields = @file.file_doc_fields.where("is_active = 0 AND doc_id = #{doc_entity.doc_id} AND tag LIKE '%NOTARY_%#{id}' AND tag NOT LIKE '%TREE%' ")
    when "tree_signature"
      id="#{doc_entity.id}_TREE#{split_id}"
      tree_signature = RolodexSignatureEntity.find split_id
      @file = Index.where("FileID = #{doc_entity.file_id}").first
      fields = @file.file_doc_fields.where("is_active = 1 AND doc_id = #{doc_entity.doc_id} AND tag LIKE '%NOTARY_%#{id}' ")
      inactive_fields = @file.file_doc_fields.where("is_active = 0 AND doc_id = #{doc_entity.doc_id} AND tag LIKE '%NOTARY_%#{id}' ")
    end

    tag = doc_entity.tag

    if fields.size > 0 # Active Notary Fields Found. Turn them off.
      fields.each do |field|
        field.is_active = 0
        field.updated_by = current_user.employee_id
        field.updated_at = Time.now.to_s(:db)
        field.save
      end
    else
      # No ACTIVE fields found. Turn some on.
      if inactive_fields.size > 0
        inactive_fields.each do |field|
          if field.tag.include?("VESTING")
            if type == "signature"
              field.value = create_notary(doc_signature, type)
            elsif type == "tree_signature"
              field.value = create_notary(tree_signature, type)
            else
              field.value = create_notary(doc_entity, "entity")
            end
          end
          field.is_active = 1
          field.updated_by = current_user.employee_id
          field.updated_at = Time.now.to_s(:db)
          field.save
        end
      else
        # Create new fields if no inactive are found
        list.each do |tag|
          field = FileDocField.new
          field.doc_id = doc_entity.doc_id
          field.file_id = @file.FileID
          field.tag = "#{doc_entity.tag}_#{tag}_#{id}"
          field.is_active = 1
          field.created_by = current_user.employee_id
          field.updated_by = current_user.employee_id
          field.created_at = Time.now.to_s(:db)
          field.updated_at = Time.now.to_s(:db)

          case tag
          when "NOTARY_VESTING"
            if type == "signature"
              field.value = create_notary(doc_signature, type)
            elsif type == "entity"
              field.value = create_notary(doc_entity, "entity")
            elsif type == "tree_signature"
              field.value = create_notary(tree_signature, "tree_signature")
            end
          else
            field.value = @file.file_doc_fields.where("tag = '#{doc_entity.tag}_#{tag}' AND is_active = 1").first.value
          end
          field.save
        end
      end
    end

    if type != "entity"
      field = @file.file_doc_fields.where("is_active = 1 AND doc_id = #{doc_entity.doc_id} AND tag = '#{doc_entity.tag}_NOTARY_VESTING_#{doc_entity.id}' ").first
      if field != nil
        field.value = create_notary(doc_entity, "entity")
        field.updated_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.save
      end
    end
  end

  def create_invoice(doc, entity)
    invoice = Invoice.new
    invoice.from_ftweb = -1 # This is set to show that invoice is from new system for accounting
    invoice.Fileid = doc.file_id
    invoice.DisplayFileID = doc.file_id.to_s[3..-1]
    invoice.DeliverTo = entity.name
    invoice.InvoiceEmployeeID = current_user.employee_id
    invoice.EmployeeInitials = "#{current_user.first_name[0]}#{current_user.last_name[0]}"
    invoice.CompanyID = @file.Company
    invoice.EnteredBy = current_user.employee_id
    invoice.EnteredDT = Time.now.to_s(:db)
    invoice.BillToName = entity.name
    invoice.BillToAddr1 = entity.address_with_2[0]
    invoice.BillToAddr1 = entity.address_with_2[1]
    invoice.BillToCSZip = "#{"#{entity.address_with_2[2]}, " if entity.address_with_2[2] != ""}#{"#{entity.address_with_2[3]} " if entity.address_with_2[3] != ""}#{entity.address_with_2[4]}"
    invoice.BillToPhoneNum =  entity.entity_contacts.primary_phone.Contact if entity.entity_contacts.primary_phone != nil
    invoice.EntityID = entity.EntityID

    if @file.TransactionDescription1 == ("Refinance" || "Construction Loan")
      invoice.Owner = @file.file_doc_fields.where("doc_id = 0 AND tag = 'GRANTEE_NAMES' ").first.value
    else
      invoice.Owner = @file.file_doc_fields.where("doc_id = 0 AND tag = 'GRANTOR_NAMES' ").first.value
    end

    invoice.PropertyID = @file.file_doc_fields.where("doc_id = 0 AND tag = 'PROPERTY_ADDRESS' ").first.value

    invoice.save
    return invoice
  end

  def create_notary(e, type)
    file = Index.where("FileID = #{@doc_entity.file_id}").first
    split = []
    file.file_doc_fields.where("is_active = 1 AND doc_id = #{@doc_entity.doc_id} AND tag LIKE '#{@doc_entity.tag}_NOTARY_VESTING_%' ").each do |field|
      id = field.tag.split("_")[-1].to_i
      if id != 0
        split << id
      end
    end
    split.uniq!

    # Tree Signatures
    tree_split = []
    file.file_doc_fields.where("is_active = 1 AND doc_id = #{@doc_entity.doc_id} AND tag LIKE '#{@doc_entity.tag}_NOTARY_VESTING_%TREE%'").each do |field|
      id = field.tag.split("_")[-1].gsub("TREE", "").to_i
      tree_split << id
    end
    tree_split.uniq!

    if type == "signature"
      return "#{e.signature} of #{@doc_entity.entity.name}"
    elsif type == "tree_signature"
      @signature = RolodexSignature.find e.rolodex_signature_id
      parent = @signature.rolodex_signature_entities.where("parent_id = 0").first
      type = parent.type.blank? ? parent.entity.IndCorp : parent.type

      case type
      when "Corporation"
        starter = get_block_notary(parent, tree_split, "Corporation1", e)
        if starter != ""
          result = "#{starter}, who being by me duly sworn, did say that "
          result += "#{get_block_notary(parent, tree_split, "Corporation2", e)} of #{parent.name.gsub(/\r?\n/, " ")}, and that said instrument was signed in behalf of said corporation by authority of its by-laws (or by a resolution of its board of directors) and said "
          result += "#{get_block_notary(parent, tree_split, "Corporation3", e)} duly acknowledged to me that said corporation executed the same and that the seal affixed is the seal of said corporation"
          value = result
        else
          value = ""
        end
      when "LLC"
        starter = get_block_notary(parent, tree_split, "Corporation1", e)
        if starter != ""
          result = "#{starter}, who being by me duly sworn, did say that "
          result += "#{get_block_notary(parent, tree_split, "Corporation2")} "
          result += "#{get_block_notary(parent, tree_split, "LLC")}"
          value = result
        else
          value = ""
        end
      else
        value = get_block_notary(parent, tree_split, type, e)
      end

      return value
    elsif type == "entity"
      value = ""

      if e.entity.IndCorp == "Individual"
        if e.entity.Prefix == "Mr."
          gender = "he"
        elsif e.entity.Prefix == "Mrs." || e.entity.Prefix == "Ms."
          gender = "she"
        else
          gender = "they"
        end

        signature = e.rolodex_signature.rolodex_signature_entities.first
        signature.title != nil && signature.title != "" ? value = "#{signature.name}, #{signature.title}" : value = "#{signature.name}"
        value != "" ? value = "#{value}, the signer(s) of the above agreement who duly acknowledge to me that #{gender} executed the same" : value = ""
      elsif e.rolodex_signature_id == nil
        e.file_doc_entity_signatures.where("is_active = -1 and signature IS NOT NULL").each do |s|
          unless split.include?(s.id)
            if value == ""
             s.signature != nil ? value = "#{s.signature}" : value = "#{s.name}"
            else
              s.signature != nil ? value += " and #{s.signature}" : value += " and #{s.name}"
            end
          end
        end
        if value != ""
          value += " of #{e.entity.name}"
        end
      elsif e.rolodex_signature_id != nil
        parent     = RolodexSignatureEntity.where("rolodex_signature_id = #{e.rolodex_signature_id} AND parent_id = 0").first
        @signature = RolodexSignature.find e.rolodex_signature_id
        type = parent.type.blank? ? e.entity.IndCorp : parent.type

        case type
        when "Corporation"
          starter = get_block_notary(parent, tree_split, "Corporation1")
          if starter != ""
            result = "#{starter}, who being by me duly sworn, did say that "
            result += "#{get_block_notary(parent, tree_split, "Corporation2")} of #{parent.name.gsub(/\r?\n/, " ")}, and that said instrument was signed in behalf of said corporation by authority of its by-laws (or by a resolution of its board of directors) and said "
            result += "#{get_block_notary(parent, tree_split, "Corporation3")} duly acknowledged to me that said corporation executed the same and that the seal affixed is the seal of said corporation"
            value = result
          else
            value = ""
          end
        when "LLC"
          starter = get_block_notary(parent, tree_split, "Corporation1")
          if starter != ""
            result = "#{starter}, who being by me duly sworn, did say that "
            result += "#{get_block_notary(parent, tree_split, "Corporation2")} "
            result += "#{get_block_notary(parent, tree_split, "LLC")}"
            value = result
          else
            value = ""
          end
        else
          value = get_block_notary(parent, tree_split, type)
        end
      end
      return value
    end
    return ""
  end

  def update_notary(file_id, tag, doc_id = 0)
    file  = Index.where("FileID = #{file_id}").first
    value = ""
    gender = ""

    # Split Signatures
    split = []
    file.file_doc_fields.where("is_active = 1 AND doc_id = #{doc_id} AND tag LIKE '#{tag}_NOTARY_VESTING_%'").each do |field|
      id = field.tag.split("_")[-1].to_i
      if id != 0
        split << id
      end
    end
    #split.uniq!

    # Tree Signatures
    tree_split = []
    file.file_doc_fields.where("is_active = 1 AND doc_id = #{doc_id} AND tag LIKE '#{tag}_NOTARY_VESTING_%TREE%'").each do |field|
      id = field.tag.split("_")[-1].gsub("TREE", "").to_i
      tree_split << id
    end
    #tree_split.uniq!

    all = file.file_doc_entities.where("doc_id = #{doc_id} AND tag = '#{tag.upcase}' AND is_active != 0")
    individuals = file.file_doc_entities.find(:all, joins: [:entity], conditions: ["tblEntities.IndCorp = 'Individual' AND doc_id = #{doc_id} AND tag = '#{tag.upcase}' AND is_active != 0"])
    individuals.each do |e|
      unless split.include?(e.id)
        if gender == ""
          if e.entity.Prefix == "Mr."
            gender = "he"
          elsif e.entity.Prefix == "Mrs." || e.entity.Prefix == "Ms."
            gender = "she"
          else
            gender = "they"
          end
        else
          gender = "they"
        end

        signature = e.rolodex_signature.rolodex_signature_entities.first rescue nil
        if signature == nil
          signature = RolodexSignatureEntity.where("entity_id = #{e.entity_id}").first
        end

        if signature == nil
          next
        end

        if value == ""
          signature.title != nil ? value = "#{signature.name}, #{signature.title}" : value = "#{signature.name}"
        else
          signature.title != nil ? value += " and #{signature.name}, #{signature.title}" : value += " and #{signature.name}"
        end
      end
    end

    gender = "they" if gender == ""

    if value != ""
      value += ", the signer(s) of the above agreement who duly acknowledge to me that #{gender} executed the same"
    end

    companies = all - individuals
    companies.each do |e|
      unless split.include?(e.id)
        if e.rolodex_signature_id == nil
          e.file_doc_entity_signatures.where("is_active = -1 and signature IS NOT NULL").each do |s|
            unless split.include?(s.id)
              if value == ""
                s.signature != nil ? value = "#{s.signature}" : value = "#{s.name}"
              else
                s.signature != nil ? value += " and #{s.signature}" : value += " and #{s.name}"
              end
            end
          end
          if value != ""
            value += " of #{e.entity.name}"
          end
        elsif e.rolodex_signature_id != nil
          if file.file_doc_entities.where("is_active = 1 AND doc_id = #{doc_id} AND tag = '#{tag.upcase}'").count <= 1
            parent = RolodexSignatureEntity.where("rolodex_signature_id = #{e.rolodex_signature_id} AND parent_id = 0").first
            @signature = RolodexSignature.find e.rolodex_signature_id
            type = parent.type.blank? ? e.entity.IndCorp : parent.type

            case type
            when "Corporation"
              result = "#{get_block_notary(parent, tree_split, "Corporation1")}, who being by me duly sworn, did say that "
              result += "#{get_block_notary(parent, tree_split, "Corporation2")} of #{parent.name.gsub(/\r?\n/, " ")}, and that said instrument was signed in behalf of said corporation by authority of its by-laws (or by a resolution of its board of directors) and said "
              result += "#{get_block_notary(parent, tree_split, "Corporation3")} duly acknowledged to me that said corporation executed the same and that the seal affixed is the seal of said corporation"
              value = result
            when "LLC"
              result = "#{get_block_notary(parent, tree_split, "Corporation1")}, who being by me duly sworn, did say that "
              result += "#{get_block_notary(parent, tree_split, "Corporation2")} "
              result += "#{get_block_notary(parent, tree_split, "LLC")}"
              value = result
            else
              if value == ""
                value = get_block_notary(parent, tree_split, type)
              else
                result = get_block_notary(parent, tree_split, type)
                value += " and #{result}" if result != ""
              end
            end
          else
            doc_entity = FileDocEntity.find e.id
            perform_toggle("entity", e.doc_id, e.id, doc_entity)
          end
        end
      end
    end

    field = file.file_doc_fields.where("tag = '#{tag.upcase}_NOTARY_VESTING' AND doc_id=#{doc_id}").first

    if field != nil
      value != "" ? field.value = "#{value}" : field.value = ""
      field.updated_at = Time.now.to_s(:db)
      field.updated_by = current_user.employee_id
      field.save
    else
      list = ["NOTARY_VESTING", "NOTARY_DATE","NOTARY_COUNTY","NOTARY_STATE"]
      list.each do |list_tag|
        default          = file.file_doc_fields.where("tag = '#{tag.upcase}_#{list_tag}' AND doc_id=0").first
        field            = FileDocField.new
        field.doc_id     = doc_id
        field.file_id    = file.FileID
        field.tag        = "#{tag.upcase}_#{list_tag}"
        field.is_active  = 1
        field.updated_at = Time.now.to_s(:db)
        field.updated_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.created_by = current_user.employee_id

        case list_tag
        when "NOTARY_VESTING"
          value != "" ? field.value = "#{value}" : field.value = ""
        else
          field.value = default.value
        end
        field.save
      end
    end
  end

  def get_block_notary(parent, split, type = "default", leaf = nil)
    if split.include?(parent.id)
      return ""
    end

    parent_value = ""
    child_value = ""

    if @signature.rolodex_signature_entities.where("parent_id = #{parent.id}").first == nil
      if leaf != nil && parent != leaf
        return ""
      end

      case type
      when "Corporation1"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      when "Corporation2"
        return "the said #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", is the #{parent.title}" if parent.title != nil}"
      when "Corporation3"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      when "LLC"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      when "Trust"
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}"
      else
        return "#{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", #{parent.title}" if parent.title != nil}"
      end
    else
      @signature.rolodex_signature_entities.where("parent_id = #{parent.id}").order("sort_order ASC").each do |child|
        child_value = ""
        if parent_value == ""
          child_value = get_block_notary(child, split, type, leaf)
        else
          result = get_block_notary(child, split, type, leaf)
          if result != ""
            child_value +=  " and #{result}"
          end
        end
        if child_value != ""
          parent_value += "#{child_value}"
        end
      end
      if parent.parent_id == 0 && parent_value != ""
        case type
        when "LLC"
          parent_value = " of #{parent.name.gsub(/\r?\n/, " ")}, the Limited Liability Company that executed the herein instrument and acknowledged the instrument to be the free and voluntary act and deed of the Limited Liability Company, by authority of statute, its articles of organization or its operating agreement, for the uses and purposes herein mentioned, and on oath stated that they are authorized to execute this instrument on behalf of the Limited Liability Company"
        when "Partnership"
          parent_value += " General Partner(s) of #{parent.name.gsub(/\r?\n/, " ")}, the signer(s) of the within instrument, who duly acknowledge to me that they executed the same for and in behalf of said partnership"
        when"Trust"
          parent_value += ", Trustee(s) of #{parent.name.gsub(/\r?\n/, " ")}, the signer(s) of the above agreement who duly acknowledge to me that they executed the same"
        else
          unless type.include?("Corporation")
            parent_value += " of #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", #{parent.title}" if parent.title != nil }, the signer(s) of the above agreement who duly acknowledge to me that they executed the same"
          end
        end
      elsif parent_value != ""
        parent_value += " of #{parent.name.gsub(/\r?\n/, " ") rescue 'NULL'}#{", #{parent.title}" if parent.title != nil }"
      end
    end

    return parent_value
  end

  def record_exists
    @tag = @field.gsub("global_", "").gsub("custom_", "").upcase
    if @file.file_doc_fields.where("tag = '#{@tag}'").count > 0
      if @file.file_doc_fields.where("tag = '#{@tag}'").last.value == @value
        return false
      else
        return true
      end
    else
      return true
    end
  end

  def generate_doc_fields(docs)
    #docs = @file.docs

    @w = {}
    @x = []
    @y = []
    @z = []

    docs.each do |d|
      @x << d.template_text.to_s.scan(/\{{(.*?)\}}/)
    end
    @x.each do |a|
      @y << a
    end
    @y.each do |i|
      i.each do |s|
        @z << s
      end
    end

    @z.each do |i|
      if @file.file_doc_fields.size > 0
        @file.file_doc_fields.each do |f|
          if i[0].downcase == f.tag.downcase
            @w[i[0]] = f.value
          else
            if @w[i[0]] == nil
              @w[i[0]] = ""
            end
          end
        end
      else
        @w[i[0]] = ""
      end
    end
    return @w
  end

  def get_written_date(date, type='none')
    month_list = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    if type == 'none'
      d = date.to_s.split(" ")
      d = d[0].split("-")

      day_number = d[2].to_s
      if day_number[0] == "0"
        day_number = day_number[-1]
      end

      if day_number[-1] == "1"
        day = "#{day_number}st"
      elsif day_number[-1] == "2"
        day = "#{day_number}nd"
      elsif day_number[-1] == "3"
        day = "#{day_number}rd"
      else
        day = "#{day_number}th"
      end

      month = month_list[d[1].to_i - 1]
      year  = d[0].to_s
    else
      d = date.split("/")

      day_number = d[1]
      if day_number[0] == "0"
        day_number = day_number[-1]
      end

      if day_number[-1] == "1"
        day = "#{day_number}st"
      elsif day_number[-1] == "2"
        day = "#{day_number}nd"
      elsif day_number[-1] == "3"
        day = "#{day_number}rd"
      else
        day = "#{day_number}th"
      end

      month = month_list[d[0].to_i - 1]
      year  = d[2]
    end

    # return "#{day} day of #{month}, A.D. #{year}"
    return "____ day of #{month}, A.D. #{year}"
  end

  # def currency_to_string(amount)
  #   amount = amount.to_s
  #   dollars, cents = amount.split["."]
  #   if dollars.to_f > 0
  #     split = dollars.split(",")
  #     case split.size
  #     when 4
  #       section = "Billion"
  #     when 3
  #       section = "Million"
  #     when 2
  #       section = "Thousand"
  #     when 1
  #       section = "Hundred"
  #     end
  #     dollars = get_number_names(split[0], section, split[1..-1])
  #   else
  #     dollars = "Zero"
  #   end

  #   return "#{dollars} and #{cents}/100 Dollars"
  # end

  # def get_number_names(current, section, list)
  #   if list.size < 1
  #     return
  #   end

  #   n = current.split("").size
  #   n.times do |i|
  #     number = current[i..-1].to_i
  #     if 100 > number && number > 9
  #       case current[i].to_i
  #       when 9
  #         return "Ninety #{get_number_names(current[])}"
  #       when 8
  #       when 7
  #       when 6
  #       when 5
  #       when 4
  #       when 3
  #       when 2
  #       when 1
  #       end
  #     end
  #   end
  # end

  def initialize_other_standard_doc_fields(doc)
    name = doc.doc_template.short_name
    case name
    when "ACK"
      fields = ["ACK_REMOVE_EXCEPTIONS", "ACK_CONDITIONS", "ACK_WATER_RIGHTS"]
    when "TPA"
      fields = ["TPA_PRO_RATION_YEAR"]
    when "RF"
      fields = nil
    when "TCI"
      fields = ["TCI_GRANTOR_NAMES", "TCI_ADDITIONAL_CONDITIONS"]
    when "TD"
      fields = ["TD_AMOUNT"]
    when "TDS"
      fields = ["TD_AMOUNT"]
    when "TDL"
      fields = ["TD_AMOUNT"]
    when "TDN"
      fields = ["TD_AMOUNT", "TD_AMOUNT_WRITTEN"]
    when "SL", "BL"
      fields = ["CLOSER_PHONE", "CLOSER_FAX"]
    end

    if fields != nil
      file_fields = @file.file_doc_fields.where("tag like '#{name}_%' ")
      fields.each do |tag|
        unless (file_fields.include?(tag) || @file.file_doc_fields.where("tag = '#{tag}' AND doc_id = 0").first != nil)
          field = FileDocField.new
          field.doc_id = 0
          field.file_id = @file.FileID
          field.tag = tag
          field.is_active = 1
          field.created_by = current_user.employee_id
          field.updated_by = current_user.employee_id
          field.created_at = Time.now.to_s(:db)
          field.updated_at = Time.now.to_s(:db)
          field.value = ""

          case tag
          when "ACK_WATER_RIGHTS"
            field.value = "There are no water rights transferred with this transaction."
          when "TPA_PRO_RATION_YEAR"
            field.value = Time.now.year
          when "TCI_GRANTOR_NAMES"
            value = ""
            file_doc_entities = @file.file_doc_entities.where("tag = 'GRANTOR' AND doc_id = 0 AND is_active != 0")
            count = file_doc_entities.size
            n = 0
            file_doc_entities.each do |e|
              n += 1
              if value == ""
                value = e.entity.name
              elsif n < count
                value += ", #{e.entity.name}"
              else
                value += " and #{e.entity.name}"
              end
            end
            field.value = value
          when "TD_AMOUNT"
            schedule_a_old = @file.property_reports.last
            field.value = number_to_currency(schedule_a_old.Policy2Amount.to_f, unit: "") if schedule_a_old != nil
          # when "TD_AMOUNT_WRITTEN"
          #   schedule_a_old = @file.property_reports.last
          #   field.value = currency_to_string(schedule_a_old.Policy2Amount.to_f) if schedule_a_old != nil
          when "CLOSER_FAX"
            closer_name = @file.file_doc_fields.where("doc_id = 0 AND tag = 'CLOSER_NAME' AND is_active != 0 ").first.value rescue nil
            closer = Employee.where("FullName = '#{closer_name}'").first
            closer = @file.closers.first if closer.blank?
            field.value = number_to_phone(closer.DirectFax, area_code: true) unless closer.blank?
          when "CLOSER_PHONE"
            closer_name = @file.file_doc_fields.where("doc_id = 0 AND tag = 'CLOSER_NAME' AND is_active != 0 ").first.value rescue nil
            closer = Employee.where("FullName = '#{closer_name}'").first
            closer = @file.closers.first if closer.blank?
            field.value = number_to_phone(closer.DirectPhone, area_code: true) unless closer.blank?
          else
            field.value = "NONE"
          end
          field.save
        end
      end
    elsif name == "RF" && @file.docs.find(:all, conditions: ["docs.is_active = -1 AND doc_templates.short_name = 'RF' "], include: [:doc_template], order: ["doc_templates.short_name ASC"]).count <= 1
       if @file.file_doc_fields.where("tag = 'RECORDING_DATE' AND doc_id = 0 AND is_active != 0").first == nil
        field = FileDocField.new
        field.doc_id = 0
        field.file_id = @file.FileID
        field.tag = "RECORDING_DATE"
        field.is_active = 1
        field.created_by = current_user.employee_id
        field.updated_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.updated_at = Time.now.to_s(:db)
        field.value = @file.COEDate.strftime("%m/%d/%Y") if @file.COEDate != nil
        field.save
      end

      @file.file_doc_fields.where("(tag LIKE 'RF_INST%' OR tag LIKE 'RF_FROM%' OR tag LIKE 'RF_TO%') and doc_id = 0").each do |rf_field|
        rf_field.is_active = 0
        rf_field.save
      end

      tags = ["RF_INST", "RF_FROM", "RF_TO"]
      n = 0
      @file.docs.find(:all, conditions: ["docs.is_active = -1 AND doc_templates.sub_category = 'Recording' "], include: [:doc_template], order: ["doc_templates.short_name ASC"]).each do |doc|
        n += 1
        doc_name = doc.doc_template.short_name
        doc_name = "TD" if (doc_name == "TDS" || doc_name == "TDL")
        tags.each do |tag|
          field = FileDocField.new
          field.doc_id = 0
          field.file_id = @file.FileID
          field.tag = "#{tag}_#{n}"
          field.is_active = 1
          field.created_by = current_user.employee_id
          field.updated_by = current_user.employee_id
          field.created_at = Time.now.to_s(:db)
          field.updated_at = Time.now.to_s(:db)
          case tag
          when "RF_INST"
            field.value = doc_name
          when "RF_FROM"
            case doc_name
            when "TD"
              value = doc.file_doc_fields.where("is_active = 1 AND tag = 'GRANTEE_NAMES' ").first.value rescue nil
              (value != nil && value != "") ? field.value = value : field.value = @file.file_doc_fields.where("is_active = 1 AND tag = 'GRANTEE_NAMES' ").first.value
            else
              value = doc.file_doc_fields.where("is_active = 1 AND tag = 'GRANTOR_NAMES' ").first.value rescue nil
              (value != nil && value != "") ? field.value = value : field.value = @file.file_doc_fields.where("is_active = 1 AND tag = 'GRANTOR_NAMES' AND doc_id = 0 ").first.value
            end
          when "RF_TO"
            case doc_name
            when "TD"
              value = doc.file_doc_fields.where("is_active = 1 AND tag = 'LENDER_NAME' ").first.value rescue nil
              if (value != nil && value != "")
                field.value = value
              else
                field.value = @file.file_doc_fields.where("is_active = 1 AND tag = 'LENDER_NAME' ").first.value rescue ""
              end
            else
              value = doc.file_doc_fields.where("is_active = 1 AND tag = 'GRANTEE_NAMES' ").first.value rescue nil
              (value != nil && value != "") ? field.value = value : field.value = @file.file_doc_fields.where("is_active = 1 AND tag = 'GRANTEE_NAMES' AND doc_id = 0 ").first.value
            end
          end
          field.save
        end
      end
    end
  end

  def initialize_doc_fields(doc, secondary = nil)
    entity          = Entity.find doc.doc_entity.entity_id
    address         = entity.address
    docs            = [doc]
    fields          = generate_doc_fields(docs)
    time            = Time.now.to_s(:db)
    standard_fields = ["SIGNATURES", "DOC_ID", "FILE_ID"]
    existing_fields = []

    if doc.doc_template.short_name == "INV"
      invoice = create_invoice(doc, entity)
      doc.invoice_id = invoice.InvoiceID
      doc.save
    end

    DocStandardField.all.each do |i|
      standard_fields << i.tag
    end

    DocBlock.all.each do |i|
      standard_fields << i.tag
    end

    file = Index.where("FileID = #{doc.file_id} ").first

    file.file_doc_fields.where("tag LIKE '#{doc.doc_template.short_name}_%_#{doc.doc_entity_id}' AND is_active = 1 AND doc_id = 0"). each do |i|
      existing_fields << i.tag
    end

    fields.each do |k, v|
      unless standard_fields.include?(k)
        value = ""

        case k
        when "1099_SELLER_NAME"
          if secondary == nil
            value = entity.name_last_first
          else
            secondary_entity = FileDocEntity.find(secondary).entity
            secondary_name = entity.IndCorp == "Individual" && secondary_entity.IndCorp == "Individual" ? secondary_entity.name_last_first.split(",")[1..-1].join(",") : secondary_entity.name_last_first
            value = "#{entity.name_last_first} and #{secondary_name}"

            [doc.doc_entity_id, secondary].each do |doc_entity_id|
              tmp_entity = FileDocEntity.find(doc_entity_id).entity
              doc_entity            = FileDocEntity.new
              doc_entity.doc_id     = doc.id
              doc_entity.file_id    = @file.FileID
              doc_entity.entity_id  = tmp_entity.EntityID
              doc_entity.is_active  = 1
              doc_entity.tag        = "GRANTOR"
              doc_entity.created_by = current_user.employee_id
              doc_entity.created_at = Time.now.to_s(:db)
              doc_entity.updated_by = current_user.employee_id
              doc_entity.updated_at = Time.now.to_s(:db)
              doc_entity.rolodex_signature_id = tmp_entity.rolodex_signatures.first.id
              doc_entity.save
            end
          end
        when "1099_FORWARDING"
          value = address[0]
        when "1099_CITY"
          value = address[1]
        when "1099_STATE"
          value = address[2]
        when "1099_ZIP"
          value = address[3]
        when "1099_TAX_ID"
          value = entity.TaxID || ""
        when "1099_GROSS_PROCEEDS"
          value = number_to_currency(file.SalesPrice, unit: "")
        when "W9_NAME"
          value = entity.name
        when "W9_ADDRESS"
          value = address[0]
        when "W9_CITY"
          value = address[1]
        when "W9_STATE"
          value = address[2]
        when "W9_ZIP"
          value = address[3]
        when "W9_SSN_FUNCTION"
          k = "W9_SSN"
          if entity.IndCorp == "Individual"
            value = entity.TaxID || ""
          end
        when "W9_TAX_ID_FUNCTION"
          k = "W9_TAX_ID"
          if entity.IndCorp != "Individual"
            value = entity.TaxID || ""
          end
        when "W9_TAX_CLASS_FUNCTION"
          k = "W9_TAX_CLASS_OPTION"
        when "W9_EXEMPT_PAYEE_FUNCTION"
          k = "W9_EXEMPT_PAYEE"
        end

        field = FileDocField.where("tag = '#{k}_#{doc.doc_entity_id}'").last
        if field == nil
          field            = FileDocField.new
          field.doc_id     = 0
          field.file_id    = doc.file_id
          field.tag        = "#{k}_#{doc.doc_entity_id}"
          field.value      = value
          field.created_by = current_user.employee_id
          field.updated_by = current_user.employee_id
          field.created_at = time
          field.updated_at = time
          field.is_active  = 1
        else
          field.value = value
          field.is_active = 1
          field.updated_by = current_user.employee_id
          field.updated_at = time
        end

        field.save
      end
    end
  end

  def initialize_standard_fields
    time                 = Time.now.to_s(:db)
    grantor_tax_id = ""
    grantee_tax_id = ""
    grantor_names = ""
    grantee_names = ""
    @doc_standard_fields = DocStandardField.all
    @doc_standard_fields.each do |s|
      @field            = FileDocField.new
      @field.doc_id     = 0
      @field.file_id    = @file.FileID
      @field.tag        = s.tag
      @field.value      = ""
      @field.created_by = current_user.employee_id
      @field.updated_by = current_user.employee_id
      @field.created_at = Time.now.to_s(:db)
      @field.updated_at = Time.now.to_s(:db)
      @field.is_active  = 1

      case s.tag
      when "CLOSER_NAME"
        @field.value = @file.closer.FullName rescue ""
      when "COMPANY_TAX_ID"
        @field.value = @file.company.TaxID
      when "COMPANY_NAME"
        @field.value = @file.company.CompanyName
      when "COMPANY_ADDRESS"
        @file.closer ? @field.value = "#{@file.closer.office.OfficeAddress1} #{@file.closer.office.OfficeAddress2}" : @field.value = "#{@file.company.CompanyAddr}"
      when "COMPANY_CITY"
        @file.closer ? @field.value = @file.closer.office.OfficeCity : @field.value = "#{@file.company.CompanyCity}"
      when "COMPANY_STATE"
        @file.closer ? @field.value = @file.closer.office.OfficeState : @field.value = "#{@file.company.CompanyStateAbrv}"
      when "COMPANY_ZIP"
        @file.closer ? @field.value = @file.closer.office.OfficeZip : @field.value = "#{@file.company.CompanyZip}"
      when "COMPANY_COUNTY"
        @file.closer ? @field.value = @file.closer.office.county.CountyName : @field.value = "#{@file.company.default_county.CountyName}"
      when "RECORDING_DATE"
        @field.value = @file.COEDate.strftime("%m/%d/%Y") if @file.COEDate != nil
      when "MAIL_TO"
        mail_to      = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = mail_to.entity.name rescue ""
      when "MAIL_TO_ADDRESS"
        mail_to = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' AND IsActive = -1 ").last rescue nil
        if contact != nil
          @field.value = contact.Address
          if contact.Address2 != nil && contact.Address2 != ""
            @field.value += " #{contact.Address2}"
          end
        end
      when "MAIL_TO_CITY"
        mail_to = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' AND IsActive = -1 ").last rescue nil
        if contact != nil
          @field.value = contact.City
        end
      when "MAIL_TO_STATE"
        mail_to = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' AND IsActive = -1 ").last rescue nil
        if contact != nil
          @field.value = contact.State
        end
      when "MAIL_TO_ZIP"
        mail_to = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        contact = mail_to.entity.entity_contacts.where("ContactType = 'ADDRESS' AND IsActive = -1 ").last rescue nil
        if contact != nil
          @field.value = contact.Zip
        end
      when "GRANTOR_VESTING"
        entities = FileEntity.where("FileID = #{@file.FileID} AND Position = 2")
        c = 0
        entities.each do |e|
          if @field.value == "" || @field.value == nil
            @field.value = e.entity.name
            grantor_tax_id = e.entity.TaxID if !e.entity.TaxID.blank?
          else
            @field.value += " and #{e.entity.name}"
            if grantor_tax_id != ""
              grantor_tax_id += ", #{e.entity.TaxID}" if !e.entity.TaxID.blank?
            else
              grantor_tax_id = e.entity.TaxID if !e.entity.TaxID.blank?
            end
          end
          c                   += 1
          grantor            = FileDocEntity.new
          grantor.doc_id     = 0
          grantor.file_id    = @file.FileID
          grantor.entity_id  = e.EntityID
          grantor.is_active  = 1
          grantor.split      = 1 if e.entity.IndCorp != 'Individual' && entities.size > 1
          grantor.sort_order = c
          grantor.tag        = "GRANTOR"
          grantor.created_by = current_user.employee_id
          grantor.updated_by = current_user.employee_id
          grantor.created_at = Time.now.to_s(:db)
          grantor.updated_at = Time.now.to_s(:db)

          if e.entity.rolodex_signatures.first == nil
            signature = RolodexSignature.new
            signature.entity_id = e.EntityID
            signature.description = "Primary"
            signature.created_by = current_user.employee_id
            signature.created_at = Time.now.to_s(:db)
            signature.updated_by = current_user.employee_id
            signature.updated_at = Time.now.to_s(:db)
            signature.save

            signature_primary = RolodexSignatureEntity.new
            e.entity.name != nil ? signature_primary.name = e.entity.name : signature_primary.name = ""
            signature_primary.rolodex_signature_id = signature.id
            signature_primary.rolodex_signature_entity_type_id = RolodexSignatureEntityType.where("name = '#{e.entity.IndCorp}' ").first.id rescue nil
            signature_primary.entity_id = e.EntityID
            signature_primary.sort_order = 0
            signature_primary.created_at = Time.now.to_s(:db)
            signature_primary.updated_at = Time.now.to_s(:db)
            signature_primary.parent_id = 0

            if e.entity.IndCorp == "Individual"
              signature_primary.relationship = "signature"
            else
              signature_primary.relationship = "parent"
            end

            signature_primary.save
          else
            signature = e.entity.rolodex_signatures.first
          end

          grantor.rolodex_signature_id = signature.id
          grantor.save

        end
        grantor_names = @field.value
      when "GRANTOR_NAMES"
        @field.value = grantor_names
      when "GRANTOR_NOTARY_VESTING"
        @field.value = ""
      when "GRANTOR_NOTARY_STATE"
        @field.value = Company.find(@file.Company).CompanyState rescue nil
      when "GRANTOR_NOTARY_COUNTY"
        @field.value = Company.find(@file.Company).default_county.CountyName rescue nil
      when "GRANTOR_NOTARY_DATE"
        @field.value = get_written_date(@file.COEDate) if @file.COEDate != nil
      when "GRANTOR_ADDRESS_1"
        grantor = FileEntity.where("FileID = #{@file.FileID} AND Position = 2").first
        @field.value = grantor.entity.full_address[0] rescue nil
      when "GRANTOR_ADDRESS_2"
        grantor = FileEntity.where("FileID = #{@file.FileID} AND Position = 2").first
        @field.value = grantor.entity.full_address[1] rescue nil
      when "GRANTOR_CITY"
        grantor = FileEntity.where("FileID = #{@file.FileID} AND Position = 2").first
        @field.value = grantor.entity.full_address[2] rescue nil
      when "GRANTOR_STATE"
        grantor = FileEntity.where("FileID = #{@file.FileID} AND Position = 2").first
        @field.value = grantor.entity.full_address[3] rescue nil
      when "GRANTOR_ZIP"
        grantor = FileEntity.where("FileID = #{@file.FileID} AND Position = 2").first
        @field.value = grantor.entity.full_address[4] rescue nil
      when "GRANTOR_COUNTY"
        grantor = FileEntity.where("FileID = #{@file.FileID} AND Position = 2").first
        @field.value = grantor.entity.full_address[5] rescue nil
      when "GRANTOR_SIGNING_DATE"
        @field.value = @file.COEDate.strftime("%m/%d/%Y") if @file.COEDate != nil
      when "GRANTEE_VESTING"
        entities = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)")
        c = 0
        entities.each do |e|
          if @field.value == "" || @field.value == nil
            @field.value = e.entity.name
            grantee_tax_id = e.entity.TaxID if !e.entity.TaxID.blank?
          else
            @field.value += " and #{e.entity.name}"
            if grantee_tax_id != ""
              grantee_tax_id += ", #{e.entity.TaxID}" if !e.entity.TaxID.blank?
            else
              grantee_tax_id = e.entity.TaxID if !e.entity.TaxID.blank?
            end
          end
          c                   += 1
          grantee            = FileDocEntity.new
          grantee.doc_id     = 0
          grantee.file_id    = @file.FileID
          grantee.entity_id  = e.EntityID
          grantee.is_active  = 1
          grantee.sort_order = c
          grantee.tag        = "GRANTEE"
          grantee.created_by = current_user.employee_id
          grantee.updated_by = current_user.employee_id
          grantee.created_at = Time.now.to_s(:db)
          grantee.updated_at = Time.now.to_s(:db)

          if e.entity.rolodex_signatures.first == nil
            signature = RolodexSignature.new
            signature.entity_id = e.EntityID
            signature.description = "Primary"
            signature.created_by = current_user.employee_id
            signature.created_at = Time.now.to_s(:db)
            signature.updated_by = current_user.employee_id
            signature.updated_at = Time.now.to_s(:db)
            signature.save

            signature_primary = RolodexSignatureEntity.new
            e.entity.name != nil ? signature_primary.name = e.entity.name : signature_primary.name = ""
            signature_primary.rolodex_signature_id = signature.id
            signature_primary.rolodex_signature_entity_type_id = RolodexSignatureEntityType.where("name = '#{e.entity.IndCorp}' ").first.id rescue nil
            signature_primary.entity_id = e.EntityID
            signature_primary.sort_order = 0
            signature_primary.created_at = Time.now.to_s(:db)
            signature_primary.updated_at = Time.now.to_s(:db)
            signature_primary.parent_id = 0

            if e.entity.IndCorp == "Individual"
              signature_primary.relationship = "signature"
            else
              signature_primary.relationship = "parent"
            end

            signature_primary.save
          else
            signature = e.entity.rolodex_signatures.first
          end

          grantee.rolodex_signature_id = signature.id
          grantee.save
        end
        grantee_names = @field.value
      when "GRANTEE_NAMES"
        @field.value = grantee_names
      when "GRANTEE_NOTARY_VESTING"
        @field.value = ""
      when "GRANTEE_NOTARY_STATE"
        @field.value = Company.find(@file.Company).CompanyState rescue nil
      when "GRANTEE_NOTARY_COUNTY"
        @field.value = Company.find(@file.Company).default_county.CountyName rescue nil
      when "GRANTEE_NOTARY_DATE"
        @field.value = get_written_date(@file.COEDate) if @file.COEDate != nil
      when "GRANTEE_ADDRESS_1"
        grantee  = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = grantee.entity.full_address[0] rescue nil
      when "GRANTEE_ADDRESS_2"
        grantee  = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = grantee.entity.full_address[1] rescue nil
      when "GRANTEE_CITY"
        grantee  = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = grantee.entity.full_address[2] rescue nil
      when "GRANTEE_STATE"
        grantee  = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = grantee.entity.full_address[3] rescue nil
      when "GRANTEE_ZIP"
        grantee  = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = grantee.entity.full_address[4] rescue nil
      when "GRANTEE_COUNTY"
        grantee  = FileEntity.where("FileID = #{@file.FileID} AND (Position = 1 OR Position = 7)").first
        @field.value = grantee.entity.full_address[5] rescue nil
      when "GRANTEE_SIGNING_DATE"
        @field.value = @file.COEDate.strftime("%m/%d/%Y") if @file.COEDate != nil
      when "COMMITMENT_DATE"
        property_report = @file.property_reports.last
        @field.value = property_report.EffectiveDate if property_report != nil
      when "COMMITMENT_NUMBER"
        property_report = @file.property_reports.last
        property_report != nil ? @field.value = "#{property_report.DisplayFileID}#{ " #{property_report.Amended}" if property_report.Amended != nil && property_report.Amended != "" }" : @field.value = @file.DisplayFileID
      when "PROPERTY_LEGAL_DESCRIPTION"
        property_report = @file.property_reports.last
        @field.value = property_report.TextLegal if property_report != nil
      when "PROPERTY_TYPE"
        property_report        = @file.property_reports.last
        @field.value = property_report.LandType if property_report != nil
      when "PROPERTY_ADDRESS"
        property_report        = @file.property_reports.last
        @field.value = property_report.LandAddress if property_report != nil
      when "PROPERTY_CITY"
        property_report        = @file.property_reports.last
        @field.value = property_report.LandCity if property_report != nil
      when "PROPERTY_STATE"
        property_report        = @file.property_reports.last
        @field.value = property_report.LandState if property_report != nil
      when "PROPERTY_ZIP"
        property_report        = @file.property_reports.last
        @field.value = property_report.LandZipCode if property_report != nil
      when "PROPERTY_COUNTY"
        property_report        = @file.property_reports.last
        @field.value = property_report.LandCounty if property_report != nil
      when "PROPERTY_TAX_ID"
        property_report        = @file.TaxID1
        @field.value = property_report if property_report != nil
      when "FULL_PROPERTY_ADDRESS"
        property_report        = @file.property_reports.last
        if property_report != nil
          address = property_report.LandAddress
          city = ", #{property_report.LandCity}" if property_report.LandCity != nil && property_report.LandCity != ""
          state = ", #{property_report.LandState}" if property_report.LandState != nil && property_report.LandState != ""
          @field.value = "#{address}#{city}#{state}"
        end
      when "FILE_ID_NUMBER"
        @field.value = @file.DisplayFileID
      when "LENDER_NAME"
        lender = @file.file_entities.where("Position = 3").last
        if lender != nil
          @field.value = lender.entity.name
        end
      when "LENDER_ADDRESS_1"
        lender = @file.file_entities.where("Position = 3").last
        if lender != nil
          @field.value = lender.entity.address_with_2[0]
        end
      when "LENDER_ADDRESS_2"
        lender = @file.file_entities.where("Position = 3").last
        if lender != nil
          @field.value = lender.entity.address_with_2[1]
        end
      when "LENDER_CITY"
        lender = @file.file_entities.where("Position = 3").last
        if lender != nil
          @field.value = lender.entity.address_with_2[2]
        end
      when "LENDER_STATE"
        lender = @file.file_entities.where("Position = 3").last
        if lender != nil
          @field.value = lender.entity.address_with_2[3]
        end
      when "LENDER_ZIP"
        lender = @file.file_entities.where("Position = 3").last
        if lender != nil
          @field.value = lender.entity.address_with_2[4]
        end
      when "SETTLEMENT_DATE"
        @field.value = @file.COEDate.strftime("%m/%d/%Y") if @file.COEDate != nil
      when "CLOSING_DATE"
        @field.value = @file.COEDate.strftime("%m/%d/%Y") if @file.COEDate != nil
      else
        #do nothing
      end
      @field.save
    end

    hash = Hash.new
    hash["GRANTOR_TAX_ID"] = grantor_tax_id
    hash["GRANTEE_TAX_ID"] = grantee_tax_id
    hash.each do |tag, tax_id|
      if tax_id != ""
        field            = FileDocField.new
        field.doc_id     = 0
        field.file_id    = @file.FileID
        field.tag        = tag
        field.value      = tax_id
        field.created_by = current_user.employee_id
        field.updated_by = current_user.employee_id
        field.created_at = Time.now.to_s(:db)
        field.updated_at = Time.now.to_s(:db)
        field.is_active  = 1
        field.save
      end
    end

    @file.initialize_notaries
  end
end
