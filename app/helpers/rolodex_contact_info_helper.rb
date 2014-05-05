module RolodexContactInfoHelper
  def build_fedex_link(entity, contact_info)
    if entity.IndCorp == "Individual"
      to_name = entity.FullName
    else
      to_company = entity.FullName
    end
    to_address1 = contact_info.Address.gsub("#","%23") unless contact_info.Address.nil?
    to_address2 = contact_info.Address2.gsub("#","%23") unless contact_info.Address2.nil?
    to_city     = contact_info.City
    to_state    = contact_info.State != nil && contact_info.State.size == 2 ? contact_info.State.upcase : abbreviate_state(contact_info.State)
    to_zip      = contact_info.Zip
    phone       = entity.entity_contacts.primary_phone
    to_phone    = phone.Contact.gsub(/\D/,"") unless phone.nil? || phone.Contact.nil?
    email       = entity.entity_contacts.primary_email
    to_email    = email.Contact unless email.nil? || email.Contact.nil?
    link_to("FedEx", "/shipments/new?rolodex_entity=#{entity.FullName}&entity_id=#{entity.EntityID}&to_name=#{to_name}&to_company=#{to_company}&to_address1=#{to_address1}&to_address2=#{to_address2}&to_city=#{to_city}&to_state=#{to_state}&to_zip=#{to_zip}&to_phone=#{to_phone}&to_email=#{to_email}", target: "_blank")
  end
end