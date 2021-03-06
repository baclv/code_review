class OmniauthCallbacksController < ApplicationController
  skip_before_action :authenticate_user!

  def create
    auth = request.env["omniauth.auth"]
    user = AuthenticationService.call auth, current_user

    if user
      log_in user
      flash[:success] = t ".success", kind: auth.provider.humanize
      redirect_or_settings user
    else
      flash[:error] = t ".failure", kind: params[:provider].humanize
      redirect_to root_path
    end
  end

  private

  def redirect_or_settings user
    return redirect_to pull_requests_path if user.reviewer?
    return redirect_to root_path if user.chatwork? && user.room_id?
    redirect_to profile_path
  end
end
