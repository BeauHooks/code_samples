class AdminController < ApplicationController
  before_filter :authorize_user

  private
    def authorize_user
      if !@permission_view_admin
        redirect_to index_index_path, flash: { error: "You do not have permission to view this page!" }
      end
    end
end