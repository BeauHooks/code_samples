class FeedbackController < ApplicationController

  def send_bug_report
    FeedbackMailer.bug_report_email(current_user,params[:description]).deliver!
    flash[:notice] = "Bug Reported Successfully!"
    render nothing: true
  end

  def send_feature_request
    FeedbackMailer.feature_request_email(current_user,params[:description]).deliver!
    flash[:notice] = "Feature Requested Successfully!"
    render nothing: true
  end
end