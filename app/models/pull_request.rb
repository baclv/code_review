class PullRequest < ApplicationRecord
  attr_accessor :message

  STATES = {
    open: 0,
    ready: 1,
    reviewing: 2,
    commented: 3,
    conflicted: 4,
    merged: 5,
    closed: 6,
    archived: 7
  }.freeze

  enum state: STATES, _prefix: true

  belongs_to :user, optional: true

  before_save :remove_current_reviewer, on: :update
  after_create_commit{sync_data}
  after_create_commit{subscribe_repository}
  after_update_commit{sync_data if previous_changes.key?(:state)}
  after_update_commit{user&.increment!(:merged) if state_merged?}

  scope :newest, ->{order updated_at: :desc}

  scope :by_single_state, (lambda do |state_param|
    where state: state_param.to_i unless state_param.blank?
  end)

  scope :by_state, (lambda do |state_param|
    where state: state_param if state_param.any?
  end)

  scope :by_room, (lambda do |room_param|
    where users: {room_id: room_param} if room_param.any?
  end)

  scope :by_repository, (lambda do |repository_param|
    where repository_id: repository_param if repository_param.any?
  end)

  delegate :name, :room_id, :chatwork, :to_cw, :to_cc, :html_url,
    to: :user, prefix: true, allow_nil: true

  def html_url
    "https://github.com/#{full_name}/pull/#{number}"
  end

  def repository_html_url
    "https://github.com/#{full_name}"
  end

  private

  def remove_current_reviewer
    self.current_reviewer = nil unless state_reviewing?
  end

  def subscribe_repository
    subscription = Subscription.create repository_id: repository_id,
      user_id: user_id, subscriber: user_to_cc
    puts subscription.errors.full_messages
  end

  def sync_data
    ActionCable.server.broadcast "pull_requests",
      node: "#pull-request-#{id}",
      state: state_before_type_cast.to_s,
      room_id: user_room_id.to_s,
      repository_id: repository_id.to_s,
      html: PullRequestsController.render(self)

    ChatworkMessageService.call self, message
  end
end
