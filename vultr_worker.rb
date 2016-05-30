require './main'
require './errors'
require 'sidekiq'
require 'json'
require 'net/http'
require 'uri'

def get_user_id_and_token
  unless @auth_user_id && @auth_token
    uri = URI(AUTH_URL)
    response = Net::HTTP.post_form(uri, 'username' => 'vultr', 'password' => '123')
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

def get_vultr_user_info(apikey)
    uri = URI('https://api.vultr.com/v1/account/info')
    req = Net::HTTP::Get.new(uri)
    req['API-Key'] = apikey
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(req)
    end

    json = JSON.parse res.body
    balance = -json['balance'].to_f
    pending_charges = -json['pending_charges'].to_f
    last_payment_date = Time.parse json['last_payment_date']
    last_payment_amount = -json['last_payment_amount'].to_f
    current_balance = balance + pending_charges

    {
        status: :ok,
        current_balance: current_balance,
        last_payment_date: last_payment_date,
        last_payment_amount: last_payment_amount
    }
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

def do_vultr_work
  MessageSourceTokenStub.where(source: :vultr).each do |user|
    puts "user #{user.user_id}"
    uid = user.user_id
    apikey = user.content
    raise 'database data corruption' unless apikey
    info = get_vultr_user_info(apikey)
    message = {
        user_id: uid,
        title: "vultr balance #{info[:current_balance]}",
        description: "vultr balance: #{info[:current_balance]}\n" +
          "last payment date: #{info[:last_payment_date]}\n" +
          "last payment amount: #{info[:last_payment_amount]}",
        source: :vultr,
        url: 'https://my.vultr.com/'
    }
    if info
      # push to scheduler
      u, t = get_user_id_and_token
      response = Net::HTTP.post_form(URI(SCHEDULER_PUSH_URL),
                                     'user_id' => u,
                                     'token' => t,
                                     'json' => { simple_message: message }.to_json
      )
      if response.code == '200'
        begin
          json = JSON.parse(response.body)
          if json['status'] == 'ok'
            puts 'successfully pushed 1 message'
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

do_vultr_work