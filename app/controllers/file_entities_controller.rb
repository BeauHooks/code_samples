class FileEntitiesController < ApplicationController
  respond_to :html, :json, :js
  before_filter :file_user_types, only: [:create, :destroy]

  def index
  end

  def new

  end

  def show
  end

  def create
    @file = Index.find params[:index_id]
    file_entity = @file.file_entities.new
    file_entity.FileID = @file.FileID
    file_entity.DisplayFileID = @file.DisplayFileID
    file_entity.Position = params[:position]
    file_entity.EntityID = params[:entity_id]
    file_entity.save!
  end

  def edit
  end

  def update
    file_entity = FileEntity.find params[:id]
    file_entity.update_attributes(file_entity.dup.attributes.merge params.select { |k| file_entity.dup.attributes.keys.include? k })
    render nothing: true
  end

  def destroy
    file_entity = FileEntity.find params[:id]
    @file = file_entity.index
    file_entity.destroy
  end

  def search
    @file = Index.find params[:id] if params[:id]
    @entities = Entity.search_by_type("name", params[:term], false) || []
    @positions = FileUserType.all
  end

  private

  def file_user_types
    @file_user_types = FileUserType.all
  end
end
