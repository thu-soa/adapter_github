require './main'
require './errors'
require 'sidekiq'
require 'json'
require 'net/http'
require 'uri'

Sidekiq.configure_client do |config|
  config.redis = { namespace: 'Alex::SOA::Scheduler', size: 1 }
end
Sidekiq.configure_server do |config|
  config.redis = { :namespace => 'Alex::SOA::Scheduler' }
end

def get_user_id_and_token
  unless @auth_user_id && @auth_token
    uri = URI(AUTH_URL)
    response = Net::HTTP.post_form(uri, 'username' => 'github', 'password' => '123')
    # response = HTTP.post(AUTH_URL, params: { username: 'github', password: '123' })
    if response.code == '200'
      json = JSON.parse(response.body)
      if json['status'] == 'ok'
        @auth_user_id = json['user_id']
        @auth_token = json['token']
      end
    end
  end
  raise 'auth error' unless @auth_user_id && @auth_token
  [@auth_user_id, @auth_token]
end

def pull_user(username, token, user_id)
  ret = []
  t = '2016-04-23 20:27:46 +0800'
  result = `curl -s -I -u #{username}:#{token} https://api.github.com/notifications -H "If-Modified-Since: #{t}"`
  status_line = result.split("\r\n").first
  case status_line.split(' ')[1].to_i
    when 304
      # not modified
    when 200
      json_str =`curl -s -u #{username}:#{token} https://api.github.com/notifications -H "If-Modified-Since: #{t}"`
      notifications = JSON.parse(json_str)
      notifications.each do |notification|
        name = notification['full_name']
        reason = notification['reason']
        url = notification['url']
        message = {
            title: reason,
            user_id: user_id,
            url: url,
            source: 'github',
            description: "#{reason} @ #{name}",
            message_type: 'notification'
        }
        ret << message
      end
    when 404
      # error
  end
  ret
end

def do_github_work
  MessageSourceTokenStub.where(source: :github).each do |gh_user|
    puts "gh_user #{gh_user.user_id}"
    uid = gh_user.user_id
    gh_uname, gh_token = gh_user.content.split(':')
    raise 'database data corruption' unless gh_uname && gh_token
    messages = pull_user(gh_uname, gh_token, uid)
    if messages && messages.size > 0
      # push to scheduler
      u, t = get_user_id_and_token
      response = Net::HTTP.post_form(URI(SCHEDULER_PUSH_URL),
          'user_id' => u,
          'token' => t,
          'json' => {simple_message: messages}.to_json
      )
      if response.code == '200'
        begin
          json = JSON.parse(response.body)
          if json['status'] == 'ok'
            puts "successfully pushed #{messages.size} messages"
          else
            puts "push message error, status: #{json['status']}"
          end
        rescue JSON::JSONError => e
          puts e
        end
      end
    end
  end
end

class GitHubNotificationJob
  include Sidekiq::Worker

  def perform
    do_github_work
  end
end

ALL_PULLING_JOB = [GitHubNotificationJob]

class MessagePullingJob
  include Sidekiq::Worker
  def perform
    ALL_PULLING_JOB.each(&:perform_async)
    #MessagePullingJob.perform_in(30.seconds)
  end
end

do_github_work