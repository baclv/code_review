class ConflictWorker
  include Sidekiq::Worker
  sidekiq_options retry: 1

  def perform repo_id
    PullRequest.where(repository_id: repo_id, state: :ready)
               .limit(2)
               .each{|request| ConflictService.call request}
  end
end
