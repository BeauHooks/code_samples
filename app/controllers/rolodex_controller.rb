class RolodexController < ApplicationController
  respond_to :html, :json, :js
  before_filter :set_options

  def index
    @search_results = []
    if params[:entity_id]
      @search_results = [ Entity.find(params[:entity_id]) ]
    end
    @entity = @search_results.first
  end

  def show
    @entity = Entity.find(params[:id])
    @entity_contacts = @entity.entity_contacts.active_contacts
    @entity_addresses = @entity.entity_contacts.active_addresses
    @entity_notes = @entity.entity_notes
  end

  def update
    @entity = Entity.find params[:id]
    @entity.update_attributes(@entity.dup.attributes.merge params.select { |k| @entity.dup.attributes.keys.include? k })
    @entity_contacts = @entity.entity_contacts.active_contacts
    @entity_addresses = @entity.entity_contacts.active_addresses
    @entity_notes = @entity.entity_notes
    render :show
  end

  def create
    @entity = Entity.new
    params[:company] != "" && params[:company] != nil ? company = params[:company] : company = session[:company]
    @response = {}

    entity = params[:entity]
    contact_info = params[:contact_info]
    address = params[:address]
    affiliation = params[:affiliation]
    note = params[:notes]

    @entity.CompanyID = company
    @entity.EnteredBy = current_user.employee_id
    @entity.EnteredDT = Time.now.to_s(:db)
    @entity.IndCorp = entity[:IndCorp]


    @entity.Prefix = entity[:Prefix] if entity[:Prefix] != ""
    @entity.Suffix = entity[:Suffix] if entity[:Suffix] != ""
    @entity.TaxID = entity[:TaxID] if entity[:TaxID] != ""
    @entity.IsTitleCo = -1 if entity[:IndCorp] == "Title Co."
    @entity.EffectiveDate = Date.strptime("#{entity[:EffectiveDate]}", "%m/%d/%Y") if entity[:EffectiveDate] != ""
    @entity.SendDocsVia = entity[:SendDocsVia] if entity[:SendDocsVia] != ""
    (entity[:CustomType] != nil && entity[:CustomType] != "") ? @entity.CustomerType = entity[:CustomType] : @entity.CustomerType = entity[:CustomerType]

    if entity[:FullName] == nil
      full = ""
      if entity[:LastName] != nil && entity[:LastName] != ""
        @entity.LastName = entity[:LastName]
        full = "#{entity[:LastName]},"
      end

      if entity[:FirstName] != nil && entity[:FirstName] != ""
        @entity.FirstName = entity[:FirstName]
        full += " #{entity[:FirstName]}"
      end

      if entity[:MiddleInitial] != nil && entity[:MiddleInitial] != ""
        @entity.MiddleInitial = entity[:MiddleInitial]
        full += " #{entity[:MiddleInitial]}"
      end

      @entity.FullName = full.strip.upcase
    else
      @entity.FirstName = entity[:FullName]
      @entity.FullName = entity[:FullName].upcase
    end

    if entity[:Description] != "" && entity[:Description] != nil
      description = Entity.find(:all, :conditions => ["Description = \"#{entity[:Description]}\" AND FullName = \"#{@entity.FullName}\" AND IsActive = -1"], :limit => 1)
      if description.first != nil
        #do nothing
      else
        @entity.Description = entity[:Description]
      end
    end

    if @entity.save
      if address != nil && address.count > 0
        @address_array = {}
        x = 0
        address.each do |i|
          unless (i[1][:Addr1] + i[1][:City] + i[1][:State] + i[1][:Zip] + i[1][:County] == "")
            x += 1
            addr = EntityContact.new
            addr.EntityID = @entity.EntityID
            addr.ContactType = "ADDRESS"
            addr.EnteredBy = current_user.employee_id
            addr.EnteredDT = Time.now.to_s(:db)
            addr.Description = i[1][:Description] || nil

            addr.Address = i[1][:Addr1] || nil
            addr.City = i[1][:City] || nil
            addr.State = i[1][:State] || nil
            addr.Zip = i[1][:Zip] || nil
            addr.County = i[1][:County] || nil

            if i[1][:Primary] != nil
              addr.Primary = -1
              addr.IsPrimary = -1
              @entity.primary_address = addr.Address
              @entity.primary_city = addr.City
              @entity.primary_state = addr.State
              if @entity.Description == nil || @entity.Description == ""
                description = Entity.find(:all, :conditions => ["Description = \"#{addr.City}, #{addr.State}\" AND FullName = \"#{@entity}\" AND IsActive = -1"], :limit => 1)
                if description.first.blank?
                  @entity.Description = "#{addr.City}, #{addr.State}"
                end
              end
            end

            if i[1][:Type] != ""
              addr.ContactDesc = i[1][:Type]

              case i[1][:Type]
              when "Home"
                @entity.HomeAddress1 = i[1][:Addr1]
              else
                #do nothing
              end
            end
            addr.save
          end
        end
      end

      if contact_info != nil && contact_info.count > 0
        @contact_info_array = {}
        x = 0
        contact_info.each do |i|
          unless (i[1][:Info] + i[1][:Description] == "")
            x += 1
            info = EntityContact.new
            info.EntityID = @entity.EntityID
            info.Contact = i[1][:Info]
            info.ContactType = "CONTACT"
            info.EnteredBy = current_user.employee_id
            info.EnteredDT = Time.now.to_s(:db)

            if i[1][:Description] != "" && i[1][:Description] != nil
              info.Description = i[1][:Description]
            elsif i[1][:Type] != "" && i[1][:Type] != nil
              info.Description = i[1][:Type]
            else
              info.Description = info.ContactType
            end

            if i[1][:Primary] != nil
              info.Primary = -1
              info.IsPrimary = -1

              if ["Home", "Office", "Cell"].include?(i[1][:Type])
                @entity.primary_phone_number = "#{i[1][:Type]}: #{i[1][:Info]}"
              elsif i[1][:Type] == "Email"
                @entity.Email = i[1][:Info]
              end

              if @entity.Description == nil || @entity.Description == ""
                description = Entity.find(:all, :conditions => ["Description = \"#{info.Description}: #{info.Contact}\" AND FullName = \"#{@entity.FullName}\" AND IsActive = -1"], :limit => 1)
                if description.first.nil?
                  @entity.Description = "#{info.Description}: #{info.Contact}"
                end
              end
            end

            if i[1][:Type] != "" && i[1][:Type] != nil
              info.ContactDesc = i[1][:Type]

              case i[1][:Type]
              when "Cell"
                @entity.CellPhone = i[1][:Info]
              when "Email"
                if @entity.Email == nil
                  @entity.Email = i[1][:Info]
                end
              when "Fax"
                @entity.FaxNum = i[1][:Info]
              when "Home"
                @entity.HomePhone = i[1][:Info]
              when "Office"
                @entity.WorkPhone = i[1][:Info]
              when "Website"
                @entity.WebSite = i[1][:Info]
              end

              if @entity.primary_phone_number == nil && ["Home", "Office", "Cell"].include?(i[1][:Type])
                @entity.primary_phone_number = "#{i[1][:Type]}: #{i[1][:Info]}"
              end
            end
            info.save
          end
        end
      end

      if affiliation != nil && affiliation.count > 0
        @affiliation_array = {}
        x = 0
        affiliation.each do |i|
          x += 1
          @affiliation = EntityAffiliation.new
          @affiliation.EntityID1 = @entity.EntityID
          @affiliation.EntityID2 = i[1][:EntityID]
          @affiliation.ContactID1 = 0
          @affiliation.ContactID2 = 0
          @affiliation.Relationship = i[1][:Relationship] if i[1][:Relationship] != ""
          @affiliation.EnteredBy = current_user.employee_id
          @affiliation.EnteredDT = Time.now.to_s(:db)

          if i[1][:Primary] != nil
            @affiliation.Primary1 = -1
            entity = Entity.find(i[1][:EntityID])
            if entity != nil
              @entity.primary_affiliation_name = entity.name_last_first
              @entity.primary_affiliation_id = entity.EntityID
            end
          elsif @entity.primary_affiliation_name == nil
            entity = Entity.find(i[1][:EntityID])
            if entity != nil
              @entity.primary_affiliation_name = entity.name_last_first
              @entity.primary_affiliation_id = entity.EntityID
            end
          end
          @affiliation.save
        end
      end

      if note != nil && note.count > 0
        @note_array = {}
        x = 0
        note.each do |i|
          unless(i[1][:Note] == "")
            x += 1
            @note = EntityNote.new
            @note.EntityID = @entity.EntityID
            @note.NoteDT = Time.now.to_s(:db)
            @note.TakenBy = current_user.employee_id
            @note.NoteText = i[1][:Note]

            if i[1][:Remind] != "" && i[1][:Remind] != nil
              tickle = i[1][:Remind]
              split_tickle = tickle.split(' ')

              split_date = split_tickle[0].split('/')
              month = split_date[0]
              day = split_date[1]
              year = split_date[2]

              split_time = split_tickle[1].split(':')
              hour = split_time[0]
              minute = split_time[1]

              am_pm = split_tickle[2]

              if am_pm == "PM" && hour.to_i != 12
                # If it's after 12:59 pm
                hour = hour.to_i + 12
                hour = hour.to_s
              elsif am_pm == "AM" && hour.to_i == 12
                # If it's before 1:00 am
                hour = "00"
              elsif am_pm == "AM" && hour.to_i < 10
                #if it's before noon
                hour = "0#{hour}"
              end

              d = "#{year}-#{month}-#{day} #{hour}:#{minute}:00"

              @note.TickleDate = d.to_datetime
              @note.TickleEmployeeID = i[1][:To] if i[1][:Remind] != ""
            end
            @note.save
          end
        end
      end

      if @entity.Description == nil || @entity.Description == ""
        last_none = Entity.find(:all, :conditions => [" Description LIKE ?", "NONE-%"], :order => "EntityID DESC", :limit => 1)
        description = last_none.first.Description
        description = description.split("-")
        int = description[1].to_i + 1

        @entity.Description = "NONE-#{int}"
      end

      @entity.save
      @form = params[:form]
      @page = params[:page]
      @commit = params[:commit_value]
      if params[:file_id] != nil && params[:file_id] != ""
        @file = Index.where("FileID = #{params[:file_id]}").first
      end
      @check = CheckWorking.find params[:check_id] if params.has_key?(:check_id)
      @doc_id = params[:doc_id] if params.has_key?(:doc_id)
      @section = params[:section] if params.has_key?(:section)

      respond_to do |format|
        format.js { render 'rolodex/new_contact_confirmation' }
      end
    else
      render js: "$('#saving_new_contact').hide(); addToQueue('save_error_new_order', 'application/flash_notice?notice=Something went wrong with your order. If you continue to receive this error message, please contact tech support.');"
    end
  end

  def destroy
  end

  def quick_search
    if params[:search_value]
      @search_value = params[:search_value]
    end

    if params.has_key?(:post)
      @post = params[:post]
    end

    if params.has_key?(:title)
      @title = params[:title]
    else
      @title = "Rolodex Quick Search"
    end
  end

  def display_search_results
    @form = params[:form]
    if params.has_key?(:entity_id)
      @search_results = [ Entity.find(params[:entity_id]) ]
    else
      if !params[:search].empty?
        @type = params[:type].first
        include_inactive = params[:include_inactive] == 'checked' ? true : false
        if @type == "Smart Search"
          @search_results = Entity.search params[:search], per_page: 100, limit: 100, with: { is_active: [true, !include_inactive] }
        else
          @search_results = Entity.search_by_type(@type, params[:search], params[:include_inactive] == 'checked')
        end
      else
        @search_results = []
      end
    end
  end

# Move to overlays controller
  # def show_overlay
  #   @overlay = params[:overlay]

  #   case @overlay
  #   when "Contact Info"
  #     @contact_info   = EntityContact.new
  #     @contact_types  = EntityContact.contact_types
  #     @rolodex_entity = Entity.find params[:id] if params[:id]
  #   when "Address"
  #     @contact_info   = EntityContact.new
  #     @address_types  = EntityContact.address_types
  #     @rolodex_entity = Entity.find params[:id] if params[:id]
  #   when "Note"
  #     @rolodex_note   = EntityNote.new
  #     @rolodex_entity = Entity.find params[:id] if params[:id]
  #   when "Rule"
  #     @rule   = EntityRule.new
  #     @entity = Entity.find params[:id] if params[:id] != nil
  #   when "Affiliation"
  #     @rolodex_entity = Entity.find params[:id] if params[:id]
  #     if params[:search_value] != "" && params[:search_value]
  #       search = params[:search_value].gsub("'", "\\\\'").gsub("%", "").gsub("*", "%").gsub(" ", "%")
  #       conditions = "(FirstName LIKE '%#{search}%' OR LastName LIKE '%#{search}%')"

  #       if search.split("%").size == 2
  #         search = search.split("%")
  #         conditions += "OR (FirstName LIKE '%#{search[0]}%' AND LastName LIKE '%#{search[1]}%') OR (FirstName LIKE '%#{search[1]}%' AND LastName LIKE '%#{search[0]}%') AND IsActive != 0"
  #       end

  #       conditions += " AND IsActive != 0" unless params[:include_inactive] == "checked"

  #       @affiliations = Entity.where("#{conditions} AND FullName IS NOT NULL AND FullName != '' ").order("FullName ASC").limit("100")
  #     else
  #       @affiliations = []
  #     end
  #   when "User Image"
  #     @entity     = params[:id]
  #     @filebin    = FileBin.where("IsUserImage = -1").order("DirName ASC")
  #     @attachment = EntityImage.new
  #   end
  # end

  def show_children
    @rolodex_master = Entity.find(params[:id])
    respond_with @rolodex_master
  end

  def preview
    @entity = Entity.find params[:id]
    @file = Index.find(params[:file_id]) unless params[:file_id].blank?
    @check = CheckWorking.find(params[:check_id]) unless params[:check_id].blank?
    @form = params[:form] unless params[:form].blank?
    @section = params[:section] unless params[:section].blank?
    @doc_id = params[:doc_id] unless params[:doc_id].blank?

    respond_to do |format|
      format.js { render 'rolodex/js/preview' }
    end
  end

# Changed to new action, or overlay controller
  # def show_new
  #   @entity = Entity.new
  #   @page = params[:page].to_s
  #   @form = params[:form].to_s
  #   if params[:file_id] != nil
  #     @file_id = params[:file_id]
  #   end

  #   @check = CheckWorking.find params[:check_id] if params.has_key?(:check_id)
  #   @doc_id = params[:doc_id] if params.has_key?(:doc_id)
  #   @section = params[:section] if params.has_key?(:section)
  # end

  def show_entity_by_type
    entity = params[:entity]
    @type = entity[:IndCorp]
  end

  # def add_affiliation_to_new_entity
  #   @relationship = params[:relationship]
  #   @entity = Entity.find(params[:affiliation])
  # end

  # def check_for_duplicates
  #   if params[:no_show] == "true"
  #     render js: "$(\"#checking_for_duplicates\").hide();"
  #     return
  #   end

  #   name_conditions = []
  #   tax_id_conditions = []
  #   contact_conditions = []

  #   @form = params[:form] if params.has_key?(:form)
  #   @check_id = params[:check_id] if params.has_key?(:check_id)
  #   @doc_id = params[:doc_id] if params.has_key?(:doc_id)
  #   @section = params[:section] if params.has_key?(:section)
  #   @file = Index.where("FileID = #{params[:file_id]}").first if params.has_key?(:file_id)

  #   if params.has_key?(:emails)
  #     list = ""
  #     params[:emails].each do |email|
  #       unless email == ""
  #         list == "" ? list = "\"#{email}\"" : list += ", \"#{email}\""
  #       end
  #     end
  #     contact_conditions << "(tblEntityContacts.Contact IN (#{list}) AND tblEntityContacts.IsActive = -1 AND tblEntityContacts.IsInactive = 0)" unless list.blank?
  #   end

  #   if params[:ind_corp] == "Individual"
  #     first_name = params[:first_name]
  #     last_name = params[:last_name]

  #     name = []
  #     name << last_name unless last_name.blank?
  #     name << first_name unless first_name.blank?

  #     name_conditions << "(tblEntities.FullName LIKE \"#{name.join("%%")}%%\" AND IndCorp = \"Individual\")" if name.size > 0

  #     first_name = first_name[0...5]
  #     last_name = last_name[0...5]

  #     name = []
  #     name << "tblEntities.FirstName LIKE \"#{first_name}%%\"" if first_name != ""
  #     name << "tblEntities.LastName LIKE \"#{last_name}%%\"" if last_name != ""
  #     if name.size > 0
  #       name_conditions << "(" + name.join(" AND ") + " AND IndCorp = \"Individual\")"
  #     end

  #     tax_id_conditions << "tblEntities.TaxID = \"#{params[:tax_id]}\" AND IndCorp = \"Individual\"" if params[:tax_id] != ""

  #     if params.has_key?(:phones)
  #       list = ""
  #       params[:phones].each do |phone|
  #         unless phone == ""
  #           list == "" ? list = "\"#{phone}\"" : list += ", \"#{phone}\""
  #         end
  #       end
  #       contact_conditions << "(tblEntityContacts.Contact IN (#{list}) AND tblEntityContacts.ContactDesc IN (\"Home\", \"Cell\") AND tblEntityContacts.IsActive = -1 AND tblEntityContacts.IsInactive = 0)" if list != ""
  #     end
  #   else
  #     name = []
  #     full_name = params[:name]
  #     full_name.split(" ").each do |sub|
  #       name << sub[0...5]
  #     end
  #     name = name[1..-1] if name.size > 0 && name[0].downcase == "the"
  #     name_conditions << "tblEntities.FullName LIKE \"%%#{name.join("%%")}%%\" AND IndCorp != \"Individual\"" if name.size > 0

  #     tax_id_conditions << "tblEntities.TaxID = \"#{params[:tax_id]}\" AND IndCorp != \"Individual\"" if params[:tax_id] != ""

  #     if params.has_key?(:phones)
  #       list = ""
  #       params[:phones].each do |phone|
  #         unless phone == ""
  #           list == "" ? list = "\"#{phone}\"" : list += ", \"#{phone}\""
  #         end
  #       end
  #       contact_conditions << "(tblEntityContacts.Contact IN (#{list}) AND tblEntityContacts.ContactDesc = \"Office\" AND tblEntityContacts.IsActive = -1 AND tblEntityContacts.IsInactive = 0)" if list != ""
  #     end
  #   end

  #   if name_conditions.size + tax_id_conditions.size + contact_conditions.size == 0
  #     render js: "$(\"#checking_for_duplicates\").hide();"
  #   else
  #     @duplicates_hash = Hash.new
  #     name_conditions.size > 0 ? name_duplicates = Entity.find(:all, conditions: [name_conditions.join(" OR ")], order: "tblEntities.FullName ASC") : name_duplicates = []
  #     tax_id_conditions.size > 0 ? tax_id_duplicates = Entity.find(:all, conditions: [tax_id_conditions.join(" OR ")], order: "tblEntities.FullName ASC") : tax_id_duplicates = []
  #     contact_conditions.size > 0 ? contact_duplicates = Entity.find(:all, conditions: [contact_conditions.join(" OR ")], include: [:entity_contacts], order: "tblEntities.FullName ASC") : contact_duplicates = []

  #     @duplicates_hash["Matches based on Name"] = name_duplicates
  #     @duplicates_hash["Matches based on Tax ID"] = tax_id_duplicates
  #     @duplicates_hash["Matches based on contact information"] = contact_duplicates

  #     type = params[:type]
  #     if (name_duplicates.size > 0 && type == "name") || (tax_id_duplicates.size > 0 && type == "tax_id") || (contact_duplicates.size > 0 && type == "contact_info")
  #       respond_to do |format|
  #         format.js
  #       end
  #     else
  #       render js: "$(\"#checking_for_duplicates\").hide();"
  #     end
  #   end
  # end

  def edit_rolodex_info
    @entity = Entity.find(params[:id])
    @field_type = params[:type]
  end

  def cancel_update_rolodex_info
    @entity = Entity.find(params[:id])
    @field_type = params[:type]
  end

  # def update_primary
  #   table = params[:box]
  #   @rolodex_entity = Entity.find params[:id]
  #   case table
  #   when "Contact Info"
  #     contacts = EntityContact.find(:all, :conditions => ["EntityID = ? AND ContactType = ?", params[:id], "CONTACT"])
  #     contacts.each do |i|
  #       if i.ContactID != params[:element_id].to_i
  #         i.Primary = 0
  #         i.IsPrimary = 0
  #         i.save
  #       else
  #         i.Primary = -1
  #         i.IsPrimary = -1
  #         i.save
  #       end
  #     end
  #   when "Address"
  #     contacts = EntityContact.find(:all, :conditions => ["EntityID = ? AND ContactType = ?", params[:id], "ADDRESS"])
  #     contacts.each do |i|
  #       if i.ContactID != params[:element_id].to_i
  #         i.Primary = 0
  #         i.IsPrimary = 0
  #         i.save
  #       else
  #         i.Primary = -1
  #         i.IsPrimary = -1
  #         i.save
  #       end
  #     end
  #   when "Affiliation"
  #     # Loop through affiliations as Entity1
  #     list = @rolodex_entity.affiliations_as_entity_1.where("Primary1 != 0") + @rolodex_entity.affiliations_as_contact_1.where("Primary1 != 0")
  #     list.each do |i|
  #       if i.ID != params[:element_id].to_i
  #         i.Primary1 = 0
  #         i.save
  #       end
  #     end
  #     # Loop through affiliations as Entity2
  #     list = @rolodex_entity.affiliations_as_entity_2.where("Primary2 != 0") + @rolodex_entity.affiliations_as_contact_2.where("Primary2 != 0")
  #     list.each do |i|
  #       if i.ID != params[:element_id].to_i
  #         i.Primary2 = 0
  #         i.save
  #       end
  #     end

  #     affiliation = EntityAffiliation.find params[:element_id]
  #     if affiliation.EntityID1 == @rolodex_entity.EntityID || affiliation.ContactID1 == @rolodex_entity.EntityID
  #       affiliation.Primary1 = -1
  #       entity = Entity.where("EntityID = #{affiliation.EntityID2}").first
  #       entity = Entity.where("EntityID = #{affiliation.ContactID2}").first if entity == nil
  #     else
  #       affiliation.Primary2 = -1
  #       entity = Entity.where("EntityID = #{affiliation.EntityID1}").first
  #       entity = Entity.where("EntityID = #{affiliation.ContactID1}").first if entity == nil
  #     end

  #     @rolodex_entity.primary_affiliation_name = entity != nil ? entity.name_last_first : nil
  #     @rolodex_entity.primary_affiliation_id = entity != nil ? entity.EntityID : nil
  #     @rolodex_entity.save
  #     affiliation.save
  #   end

  #   @type = table
  #   respond_to do |format|
  #     format.js { render 'show_contact' }
  #   end
  # end

  private

  def set_options
    @select_options = Entity::SELECT_OPTIONS
    @search_display = Entity::SEARCH_DISPLAY
  end
end