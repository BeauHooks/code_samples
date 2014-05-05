class FileDocsController < ApplicationController

  def index
    @template = DocTemplates.first
  end

  def new
    respond_to do |format|
      format.html
    end
  end
end