class EntityNotesController < ApplicationController

  def new
    @rolodex_note = EntityNote.new
    @entity       = Entity.find params[:id]
    @employees    = Employee.where("Active = -1")
    respond_to do |format|
      format.html { render layout: 'modal_box' }
      format.js
    end
  end

  def create

    @params                = params[:entity_note]
    @note                  = EntityNote.new
    @note.EntityID         = @params[:EntityID]
    @note.NoteDT           = Time.now.to_s(:db)
    @note.TakenBy          = current_user.employee_id
    @note.NoteText         = @params[:NoteText]
    @note.TickleDate       = datetime_parse(@params[:TickleDate]) rescue ""
    @note.TickleEmployeeID = @params[:TickleEmployeeID]
    @note.save

    @rolodex_entity = Entity.find(@params[:EntityID])
    @detail = @rolodex_entity
    respond_to do |format|
      format.js { render 'rolodex/update_notes' }
    end
  end
end
