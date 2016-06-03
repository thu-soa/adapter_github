require 'sinatra'
require './main'
require './errors'
require 'json'
require 'sinatra/cross_origin'
require 'http'

configure do
  enable :cross_origin
end

after do
  ActiveRecord::Base.connection.close
end
def get_user_by_token(token) 
  response = HTTP.get(URI("#{USER_INFO_URL}?token=#{token}")) 
    begin 
      json = JSON.parse(response) 
        if json['status'] == 'ok' 
          json 
        else 
          nil 
        end 
    rescue JSON::JSONError 
      raise 'auth returns garbage' 
    end 
end

post '/api/v1/register' do
  begin
    uid, token, gh_uname, gh_token =
        params.fetch_values('id', 'token', 'github_user_name', 'github_token')
  rescue KeyError
    er 'parameter error'
  end

  # get user_id from token,
  # create or update existing one

  token_stub = MessageSourceTokenStub.create(
      source: :github,
      user_id: uid,
      content: "#{gh_uname}:#{gh_token}")

  er 'database error' unless token_stub
  { status: :ok }.to_json
end

delete '/api/v1/register' do
  begin
    uid, token = params.fetch_values('id', 'token')
    er 'parameter error' unless uid && token
    stub = MessageSourceTokenStub.find_by_user_id(uid)
    if stub&.destroy
      { status: :ok }.to_json
    else
      er 'wrong id'
    end
  rescue
    er 'wrong parameter'
  end
end


get '/api/v1/check_registered' do
  begin
    token = params.fetch_values('token').first
    user = get_user_by_token(token)
    uid = user['id']
  rescue KeyError
    er 'parameter error'
  end

  # get user_id from token,
  # create or update existing one

  result = MessageSourceTokenStub.where(
      source: :github,
      user_id: uid)
  if result.size > 0
    { status: :ok, registered: true }.to_json
  else
    { status: :ok, registered: false }.to_json
  end
end

get '/api/v1/messages' do
  uid = params['id']
  token = params['token']
  github_token = 'get github token with some method'
  messages = []
  (1..10).to_a.sample.times do
    messages << { title: "title is #{Math.rand(1234566).to_s}", user_id: uid }
  end
  {
      status: :ok,
      id: uid,
      source: 'github',
      messages: messages
  }.to_json
end
