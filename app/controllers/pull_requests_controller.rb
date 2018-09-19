class PullRequestsController < ApplicationController
  before_action :ensure_reviewer!, :load_pull_request, only: :update

  def index
    @pull_requests = PullRequest.joins(:user)
                                .by_state(helpers.selected_states)
                                .by_room(helpers.selected_room)
                                .by_repository(helpers.selected_repositories)
                                .newest.page params[:page]

    respond_to :html, :js
  end

  def update
    if @pull_request.update pull_request_params
      respond_to :js
    else
      head :bad_request
    end
  end

  private

  def ensure_reviewer!
    return if current_user.reviewer?
    head :forbidden
  end

  def load_pull_request
    @pull_request = PullRequest.find_by id: params[:id]
    return if @pull_request
    head :not_found
  end

  def pull_request_params
    data = params.require(:pull_request).permit :state
    data.merge current_reviewer: current_user.name
  end
end