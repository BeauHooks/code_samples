module DocTemplateHelper
  def get_signature_options(template)
    signature_id = template.doc_template_versions.last.doc_signature_type_id if template.doc_template_versions.last != nil

    if signature_id != nil && signature_id != ""
      name = DocSignatureType.find(signature_id).name.split("_")
      return name[0], name[1]
    else
      return "", ""
    end
  end

  def group_templates(doc_group)
    list = []
    object_list = DocGroupTemplate.where("doc_group_id = #{doc_group.id}").sort! { |a,b| a.doc_template.description <=> b.doc_template.description }
    object_list.each do |template|
      list << template.doc_template.description
    end
    return list, object_list
  end

  def get_short_names()
    templates = DocTemplate.select("short_name").where("is_active != 0").order("short_name ASC")
    list = []
    templates.each do |template|
      list << template.short_name.upcase
    end

    return list
  end
end