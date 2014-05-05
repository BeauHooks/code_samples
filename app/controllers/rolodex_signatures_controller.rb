class RolodexSignaturesController < ApplicationController
  def new
    @entity_id = params[:entity]
    respond_to do |format|
      format.js { render 'new' }
    end
  end

  def edit
  end

  def edit_description
    @signature = RolodexSignature.find params[:id]
  end

  def update_description
    @signature = RolodexSignature.find params[:id]
    @signature.description = params[:description]
    @signature.updated_by = current_user.employee_id
    @signature.updated_at = Time.now.to_s(:db)
    @signature.save

    respond_to do |format|
      format.js { render 'update_description' }
    end
  end

  def create
    @rolodex_entity = Entity.find params[:entity]
    @type = "Signature"

    @signature = RolodexSignature.new
    @signature.entity_id = params[:entity]
    @signature.description = params[:description]
    @signature.created_by = current_user.employee_id
    @signature.created_at = Time.now.to_s(:db)
    @signature.updated_by = current_user.employee_id
    @signature.updated_at = Time.now.to_s(:db)
    @signature.save

    signature_primary = RolodexSignatureEntity.new
    @rolodex_entity.name != nil ? signature_primary.name = @rolodex_entity.name : signature_primary.name = ""
    signature_primary.rolodex_signature_id = @signature.id
    signature_primary.rolodex_signature_entity_type_id = RolodexSignatureEntityType.where("name = '#{@rolodex_entity.IndCorp}' ").first.id rescue nil
    signature_primary.entity_id = params[:entity]
    signature_primary.sort_order = 0
    signature_primary.created_at = Time.now.to_s(:db)
    signature_primary.updated_at = Time.now.to_s(:db)
    signature_primary.parent_id = 0

    if @rolodex_entity.IndCorp == "Individual"
      signature_primary.relationship = "signature"
    else
      signature_primary.relationship = "parent"
    end

    signature_primary.save

    if params[:doc_entity_id] != nil && params[:doc_entity_id] != ""
      @doc_entity = FileDocEntity.find params[:doc_entity_id]
      @doc_entity.rolodex_signature_id = @signature.id
      @doc_entity.save
      @file = Index.where("FileID = #{@doc_entity.file_id}").first

      if params[:force_create] == "true"
        @force_create = true
      end
      
      respond_to do |format|
        format.js { render 'overlays/manage_signature_block' }
      end
    else
      respond_to do |format|
        format.js { render 'rolodex/show_contact' }
      end
    end
  end

  def show
    @signature = RolodexSignature.find params[:id]
  end

  def show_editor
    @signature = RolodexSignature.find params[:id]
  end

  def save_block
    @signature = RolodexSignature.find params[:id]
    @signature.block_text = params[:text]
    @signature.is_active = -1
    @signature.updated_at = Time.now.to_s(:db)
    @signature.updated_by = current_user.employee_id
    @signature.save
    respond_to do |format|
      format.js { render 'show' }
    end
  end

  def revert_to_signature_builder
    @signature = RolodexSignature.find params[:id]
    @signature.block_text = nil
    @signature.updated_by = current_user.employee_id
    @signature.updated_at = Time.now.to_s(:db)
    @signature.is_active = -1
    @signature.save

    respond_to do |format|
      format.js { render 'show' }
    end
  end

  def add_to_show

  end

  def mark_active
    @signature = RolodexSignature.find params[:id]

    if @signature.is_active?
      @signature.is_active = 0
    else
      @signature.is_active = -1
    end
    @signature.save
    render nothing: true
  end

  def add_child
    parent = RolodexSignatureEntity.find params[:id]
    signature_entity = RolodexSignatureEntity.new
    signature_entity.entity_id = params[:entity] if params[:entity] != ""
    signature_entity.rolodex_signature_id = parent.rolodex_signature_id
    signature_entity.relationship = params[:type]
    signature_entity.created_at = Time.now.to_s(:db)
    signature_entity.updated_at = Time.now.to_s(:db)

    if RolodexSignatureEntity.where("parent_id = #{parent.id}").first != nil
      last = RolodexSignatureEntity.where("parent_id = #{parent.id}").order("sort_order DESC").first.sort_order
      signature_entity.sort_order = last + 1
    else
      signature_entity.sort_order = 1
    end

    signature_entity.parent_id = parent.id
    signature_entity.save

    @signature = RolodexSignature.find signature_entity.rolodex_signature_id
    respond_to do |format|
      format.js { render 'show' }
    end
  end

  def remove_child
    remove_entity = RolodexSignatureEntity.find params[:id]
    @signature = RolodexSignature.find remove_entity.rolodex_signature_id

    if RolodexSignatureEntity.where("parent_id = #{remove_entity.id}").first != nil
      RolodexSignatureEntity.where("parent_id = #{remove_entity.id}").each do |child|
        if child.relationship == "child"
          child.parent_id = remove_entity.parent_id
          child.save
        elsif child.relationship == "signature"
          child.destroy
        end
      end
    end

    remove_entity.destroy

    respond_to do |format|
      format.js { render 'show' }
    end
  end

  def update_signature_entity
    @signature_entity = RolodexSignatureEntity.find params[:id]
    params[:entity_id] ? entity = Entity.find(params[:entity_id]) : entity = nil
    params[:value] ? value = params[:value] : value = entity.name

    case params[:field]
    when "name"
      @signature_entity.name = value
    when "title"
      @signature_entity.title = value
    when "type"
      @signature_entity.rolodex_signature_entity_type_id = value
    end

    if params[:entity_id] != "" && params[:entity_id] != nil
      @signature_entity.entity_id = params[:entity_id]
    end

    @signature_entity.updated_at = Time.now.to_s(:db)
    @signature_entity.save

    if params[:no_show]
      render nothing: true
    else
      @signature = RolodexSignature.find @signature_entity.rolodex_signature_id
      @update = "update"
      respond_to do |format|
        format.js { render 'show' }
      end
    end
  end

  def entity_lookup
    @signature_entity = RolodexSignatureEntity.find params[:id]
    respond_to do |format|
      format.js { render 'entity_lookup' }
    end
  end

  def update_child_sort
    mover = RolodexSignatureEntity.find params[:id]
    @signature = RolodexSignature.find mover.rolodex_signature_id
    direction = params[:direction]

    # @doc_entity = FileDocEntity.find params[:id]
    # @rolodex_entity = Entity.find @doc_entity.entity_id
    # @signature = RolodexSignature.find @doc_entity.rolodex_signature_id

    case direction
    when "up" # Up as in moving from 2 to 1
      if mover.sort_order > 1
        shaker = @signature.rolodex_signature_entities.where("parent_id = #{mover.parent_id} AND sort_order = #{mover.sort_order - 1}").first
        shaker.sort_order += 1
        shaker.updated_at = Time.now.to_s(:db)
        shaker.save

        mover.sort_order -= 1
        mover.updated_at = Time.now.to_s(:db)
        mover.save

        @signature.updated_by = current_user.employee_id
        @signature.updated_at = Time.now.to_s(:db)
        @signature.save
      end
    when "down" # Down as in moving from 1 to 2
      if mover.sort_order < @signature.rolodex_signature_entities.where("parent_id = #{mover.parent_id}").count
        shaker = @signature.rolodex_signature_entities.where("parent_id = #{mover.parent_id} AND sort_order = #{mover.sort_order + 1}").first
        shaker.sort_order -= 1
        shaker.updated_at = Time.now.to_s(:db)
        shaker.save

        mover.sort_order += 1
        mover.updated_at = Time.now.to_s(:db)
        mover.save

        @signature.updated_by = current_user.employee_id
        @signature.updated_at = Time.now.to_s(:db)
        @signature.save
      end
    end

    respond_to do |format|
      format.js { render 'show' }
    end
  end
end
