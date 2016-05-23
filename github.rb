require 'sinatra'
require './main'
require './errors'
require 'json'

after do
  ActiveRecord::Base.connection.close
end

post '/api/v1/register' do
  begin
    uid, token, gh_uname, gh_token =
        params.fetch_values('id', 'token', 'github_user_name', 'github_token')
  rescue KeyError
    er 'parameter error'
  end

  # check uid and token

  token_stub = MessageSourceTokenStub.create(
      source: :github,
      user_id: uid,
      content: "#{gh_uname}:#{gh_token}")

  er 'database error' unless token_stub
  { status: :ok }.to_json
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
