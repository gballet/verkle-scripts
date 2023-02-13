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
  opt :fork_block, "Block number at which to fork", type: :integer
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

# Block number at which the fork happens
FORK_BLOCK = 1000
# Start a thread to poll a data delivery address
Thread.new do
  while true
    if mode == 0
      uri = URI(provider_url)
      response = Net::HTTP.get_response(uri)
      if response.code == "200"
        mode = 1
        File.write(status_file, mode)
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
  
  # Check if we reached the transition condition
  if transitionned == false && number >= fork_block
    transitionned = true
    status.update(transitionned: true)
  end

  if converted
    # Also send it to the conversion code, if it
    # is transitioned
    forward_call(vkt_url, data) unless transitionned
  else
    # Just save the call, to be replayed once the
    # conversion has completed.
    DB[:payloads].insert(data: parameters)
  end

  forward_call(transitionned ? vkt_url : mpt_url, data)
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
