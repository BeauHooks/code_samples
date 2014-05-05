module RolodexSignaturesHelper
  def tree_list(signature)
    @signature = signature
    parent = @signature.rolodex_signature_entities.where("parent_id = 0").first
    html = ""
    partial = "rolodex_signatures/add_to_show"

    if parent != nil
      html = get_children(parent, partial)
    end
    return html
  end

  def get_children(parent, partial)
    @signature_entity = parent
    html = render partial: partial

    if @signature.rolodex_signature_entities.where("parent_id = #{parent.id}").first != nil
      @signature.rolodex_signature_entities.where("parent_id = #{parent.id}").order("sort_order ASC").each do |child|
        html += get_children(child, partial)
      end
    end

    return html
  end

  def generate_signature_tree(signature)
    @signature = signature
    parent = @signature.rolodex_signature_entities.where("parent_id = 0").first
    html = ""
    partial = "rolodex_signatures/block"

    if parent != nil 
      html += get_children(parent, partial)
    end
    return html
  end

  def generate_doc_signature_tree(signature)
    @signature = signature
    parent = @signature.rolodex_signature_entities.where("parent_id = 0").first
    html = ""
    partial = "rolodex_signatures/doc_entity"

    if parent != nil 
      html += get_children(parent, partial)
    end
    return html
  end
end