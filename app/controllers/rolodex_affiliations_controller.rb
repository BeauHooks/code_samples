class RolodexAffiliationsController < ApplicationController

  def display_search_results
    @overlay = params[:overlay]
    if params[:entity] != "" && params[:entity] != nil
      @entity = Entity.find params[:entity]
    end

    if !params[:search_value].blank?
      search = params[:search_value].gsub("'", "\\\\'").gsub("%", "").gsub("*", "%").gsub(" ", "%")
      conditions = "FullName LIKE '#{search}%' AND IsActive != 0"
      @affiliations = Entity.where("#{conditions}").order("FullName ASC").limit("100")
    else
      @affiliations = []
    end
  end

  def create
    @entity                   = Entity.find(params[:entity_id])
    @affiliation              = EntityAffiliation.new
    @affiliation.EntityID1    = params[:entity_id]
    @affiliation.EntityID2    = params[:affiliation]
    @affiliation.ContactID1   = 0
    @affiliation.ContactID2   = 0
    @affiliation.Relationship = params[:relationship]
    @affiliation.EnteredBy    = current_user.employee_id
    @affiliation.EnteredDT    = Time.now.to_s(:db)
    @affiliation.save
    @rolodex_entity = Entity.find params[:entity_id] if params[:entity_id] != nil
  end

  def update
    affiliation = EntityAffiliation.find(params[:id])

    if params.has_key?("primary")
      affiliation.make_primary(params[:entity_id])
    else
      affiliation.update_attributes(affiliation.dup.attributes.merge params.select { |k| affiliation.dup.attributes.keys.include? k })
    end

    @entity = Entity.find(params[:entity_id])
  end

  def destroy
    @entity = Entity.find(params[:entity_id])
    @affiliation = EntityAffiliation.find(params[:id])
    @affiliation.IsActive = 0
    @affiliation.IsInactive = -1
    @affiliation.InactiveDT = Time.now.to_s(:db)
    @affiliation.save
  end
end