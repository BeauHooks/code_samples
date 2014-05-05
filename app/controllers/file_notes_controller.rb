class FileNotesController < ApplicationController
  def index
  end

  def show
  end

  def new
    @file = Index.find params[:id]
    @file_note = FileNote.new
    respond_to do |format|
      format.html { render layout: 'modal_box' }
      format.js
    end
  end

  def add_to_view
    @file_note = FileNote.where("FileID = #{params[:file]}").order("NoteDT DESC").first
    @file = Index.where("FileID = #{params[:file]}").first
  end

  def create
    @file         = Index.find params[:file]
    to_employee   = Employee.find(params[:file_note][:TickleEmployeeID])
    tickle_date   = params[:file_note][:TickleDate].split("/") unless params[:file_note][:TickleDate] == ""

    @file_note                  = @file.file_notes.new
    @file_note.DisplayFileID    = @file.DisplayFileID
    @file_note.NoteDT           = Time.now.to_s(:db)
    @file_note.ToEmail          = to_employee.Email
    @file_note.FromEmail        = current_user.employee.Email
    @file_note.TickleEmployeeID = params[:file_note][:TickleEmployeeID]
    @file_note.EnteredBy        = params[:file_note][:EnteredBy]
    @file_note.TickleDate       = DateTime.new(tickle_date[2].to_i, tickle_date[0].to_i, tickle_date[1].to_i).to_s(:db) unless params[:file_note][:TickleDate] == ""
    @file_note.NoteText         = params[:file_note][:NoteText]
    @file_note.save!
  end

  def edit
  end

  def update
    note = FileNote.find params[:id]
    note.update_attributes(params[:file_note])
    render nothing: true
  end

  def destroy
    note = FileNote.find params[:id]
    note.IsHidden = -1
    note.save!
    render nothing: true
  end
end
