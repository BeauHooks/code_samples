class EntityContactsController < ApplicationController
  respond_to :js, :json, :html
  before_filter :set_entity, :set_type

  def new
    entity = Entity.find(params[:rolodex_id])
    @entity_contact = entity.entity_contacts.new
  end

  def create
    case @type
    when "contact"
      primary        = @entity.primary_phone.nil? ? -1 : 0
      entity_contact = @entity.entity_contacts.new
      entity_contact.update_attributes(
        ContactType: "CONTACT",
        ContactDesc: "Home",
        Primary: primary,
        EnteredBy: current_user.employee_id,
        EnteredDT: Time.now.to_s(:db)
      )
      @entity_contacts = @entity.entity_contacts.active_contacts
    when "address"
      primary        = @entity.primary_address.nil? ? -1 : 0
      entity_contact = @entity.entity_contacts.new
      entity_contact.update_attributes(
        ContactType: "ADDRESS",
        Description: "Home",
        Primary: primary,
        EnteredBy: current_user.employee_id,
        EnteredDT: Time.now.to_s(:db)
      )
    end

    case @type
    when "contact"
      @entity_contacts = @entity.entity_contacts.active_contacts
    when "address"
      @entity_addresses = @entity.entity_contacts.active_addresses
    end
  end

  def update
    contact           = EntityContact.find params[:id]
    contact.EnteredBy = current_user.employee_id
    contact.EnteredDT = Time.now.to_s(:db)
    contact.update_attributes(contact.dup.attributes.merge params.select { |k| contact.dup.attributes.keys.include? k })
    case @type
    when "contact"
      @entity_contacts = @entity.entity_contacts.active_contacts
    when "address"
      @entity_addresses = @entity.entity_contacts.active_addresses
    end
    render nothing: true unless params[:IsPrimary]
  end

  def destroy
    @contact = EntityContact.find params[:id]
    @contact.inactive

    case @type
    when "contact"
      @entity_contacts = @entity.entity_contacts.active_contacts
    when "address"
      @entity_addresses = @entity.entity_contacts.active_addresses
    end
  end

  def activate
    @entity_contact = EntityContact.find params[:id]
    @entity = @entity_contact.entity
    @entity_contact.active

    case @type
    when "contact"
      @entity_contacts = @entity.entity_contacts.contacts
    when "address"
      @entity_addresses = @entity.entity_contacts.addresses
    end
  end

  def show_info
    @contact = EntityContact.find params[:id]
  end

  def edit_info
    # Figure out what this method does
    @contact = EntityContact.new
    @contact_types = EntityContact.contact_types
    @address_types = EntityContact.address_types
    respond_to do |format|
      format.html { render layout: 'modal_box' }
    end
  end

  def toggle_active
  end

  private

  def set_entity
    @entity = Entity.find params[:rolodex_id] if params[:rolodex_id]
  end

  def set_type
    @type = params[:type] if params[:type]
  end
end
