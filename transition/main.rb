#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'net/http'
require 'uri'
require 'sequel'
require 'optimist'

# Parse the command line arguments
opts = Optimist::options do
  opt :fork_block, "Block number at which to fork", type: :integer, default: 100000
  opt :mpt_url, "URL of the MPT backend", type: :string, default: "https://localhost:8551"
  opt :vkt_url, "URL of the verkle backend", type: :string, default: "https://localhost:8552"
  opt :provider_url, "URL to poll for the converted data"
end

fork_block = opts[:fork_block]
mpt_url = opts[:mpt_url]
vkt_url = opts[:vkt_url]
provider_url = opts[:provider_url]

POLL_PERIOD = 600

# A helper function to call one of the backends
def forward_call url, data
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  req =  Net::HTTP::Post.new(uri.path)
  req.body = data
  req['Content-Type'] = 'application/json'
  https.request(req).body.read
end

# Create the db connection
DB = Sequel.connect('sqlite://transition.db')

# Create the payloads table if it doesn't exist
DB.create_table? :payloads do
  primary_key :id
  String :data
end

# Create the status table if it doesn't exist
DB.create_table? :status do
  primary_key :id
  Integer :mode, default: 0
end

status = DB[:status].first
# Reads the mode from the database
mode = status[:mode]

# Start a thread to poll a data delivery address
Thread.new do
  while true
    if mode == 0
      uri = URI(provider_url)
      response = Net::HTTP.get_response(uri)
      if response.code == "200"
        File.write(status_file, mode)
        mode = 1
        break
      end
    end
    sleep POLL_PERIOD
  end
end

# A helper function to call one of the backends
def forward_call url, data
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  req =  Net::HTTP::Post.new(uri.path)
  req.body = data
  req['Content-Type'] = 'application/json'
  https.request(req).body.read
end

# This implements a post handler, that redirects
# each RPC call to both the verkle and MPT backends,
# until the transition block is reached.
post '/' do
  data = request.body.read
  command = JSON.parse(data)
  method = command['method']
  parameters = command['params']
  number = parameters['number'].to_i(16)  
  
  case mode
    when 0
      # Ongoing conversion, save the data to the DB in
      # order to replay it later.
      forward_call(mpt_url, data)
      DB[:payloads].insert(data: parameters, id: number)
    when 1
      # Conversion results were downloaded and applied,
      # forward to both endpoints.
      response_vkt = forward_call(vkt_url, data)
      if response_vkt["error"]
        puts "Warning: backend B returned non-null error field: #{response_vkt["error"]}"
      end
      forward_call(mpt_url, data)
  else
    # Switch block arrived, only forward to the verkle backend
    forward_call(vkt_url, data)
  end

end

# Indicate that the data has been converted. It will
# replay all saved blocks.
post '/converted' do
  DB[:payloads].each do |row|
    forward_call(vkt_url, row[:payload])
  end
  
  # Clear the table
  DB[:payloads].delete
  
  # Send a fork choice update message
  forward_call(vkt_url, {
    jsonrpc: "2.0",
    method: "engine_forkchoiceUpdatedV1",
    params: [
      {
        headBlockHash: backlog.last['hash'],
        finalizedBlockHash: '0x0000000000000000000000000000000000000000000000000000000000000000',
        safeBlockHash: '0x0000000000000000000000000000000000000000000000000000000000000000',
      }
    ]
  }.to_json)
  
  converted = true
  status.update(converted: true)
end
