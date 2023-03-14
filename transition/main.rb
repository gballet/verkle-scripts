#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sinatra/config_file'
require 'json'
require 'net/http'
require 'uri'
require 'sequel'
require 'colorize'
require 'socket'
require 'jwt'

raise "missing config.yml" unless File.exist?("./config.yml")
config_file './config.yml'

# fork_block = settings.fork_block
mpt_url = settings.mpt_url
vkt_url = settings.vkt_url
# provider_url = settings.provider_url
jwtsecret_path = settings.jwtsecret_path

secret = File.read(jwtsecret_path)

POLL_PERIOD = 600

# A helper function to call one of the backends
def forward_call url, data, token
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  # https.use_ssl = true

  req =  Net::HTTP::Post.new(uri.path)
  req.body = data
  req['Content-Type'] = 'application/json'
  req['Authorization'] = token
  response = https.request(req)
  data = response.body
  if response.code.to_i == 200
   	puts "SUCCESS! ".green + data
  else
    puts "FAILURE with code #{response.code}".red + " data=#{data}"
  end
  data
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

# Reads the mode from the database
if DB[:status].count == 0
  DB[:status].insert
end
status = DB[:status].first
mode = status[:mode]

def set_mode number
  mode = number
  DB[:status].first.update(mode: mode)
end

def ready_to_replay?
  return File.exist?("converted.tgz") && File.exist?("fork.txt")
end

def parse_fork_txt
  fields = File.read('fork.txt').split
  if fields.length != 3
    puts "Incorrect format for fork.txt"
    sleep 5
  end

  return fields[0].to_i, fields[1].to_i, fields[2]
end

def replay_entry row, fcu
  result = ""
  jsondata = JSON.parse(row[:data])
  token = JWT.encode jsondata, secret, 'HS256'
  result = forward_call(vkt_url, row[:data], token)

  result = JSON.parse(res)
  return false unless result["error"].nil?
  if fcu
    j = JSON.parse(row[:data])
    parameters = j["params"]
    hash = parameters[0]["blockHash"]
    fcujson = {
      jsonrpc: "2.0",
      method: "engine_forkchoiceUpdatedV1",
      params: [{
        finalizedBlockHash: "0x0000000000000000000000000000000000000000000000000000000000000000",
        headBlockHash: hash,
        safeBlockHash: "0x0000000000000000000000000000000000000000000000000000000000000000"
      },
      nil],
      id: 1
    }
    token = JWT.encode fcujson, secret, 'HS256'
    forward_call(vkt_url, fcujson.to_json, token)
  end
  return true
end

last_block = nil
fork_block = nil

# This implements a post handler, that redirects
# each RPC call to both the verkle and MPT backends,
# until the transition block is reached.
post '/' do
  data = request.body.read
  command = JSON.parse(data)
  method = command['method']
  if method != 'engine_newPayloadV1' && method != 'engine_newPayloadV2'
    puts "Forwarding call of #{method}".yellow
	  return forward_call(mpt_url, data, request.env['HTTP_AUTHORIZATION'])
  end
  puts "Received newPayload #{data}".yellow
  parameters = command['params']
  number = parameters[0]['blockNumber'].to_i(16)
  
  set_mode(2) if !fork_block.nil? && number >= fork_block && mode < 2
  
  case mode
    when 0
      # Ongoing conversion, save the data to the DB in
      # order to replay it later. The same call can be
      # sent multiple times, so ensure that it is only
      # saved once into the DB.
      DB[:payloads].insert(data: data, id: number) unless DB[:payloads].first(id: number)
      if !last_block.nil? || ready_to_replay?
        if last_block.nil?
          conversion_block, fork_block, converted_hash = parse_fork_txt
          last_block = conversion_block
        end
        puts "Verkle backfilling from block #{last_block}".red
        # replay all the payloads in the db
        payloads = DB[:payloads].where { id > last_block }.order(:id).limit(10)
        payloads.each do |row|
          break unless replay_entry(row, last_block % 100)
          last_block += 1
        end
        set_mode 1
      end
      forward_call(mpt_url, data, request.env['HTTP_AUTHORIZATION'])
    when 1
      # Conversion results were downloaded and applied,
      # forward to both endpoints.
      response_vkt = forward_call(vkt_url, data, request.env['HTTP_AUTHORIZATION'])
      if response_vkt["error"]
        puts "Warning: backend B returned non-null error field: #{response_vkt["error"]}"
      end
      forward_call(mpt_url, data, request.env['HTTP_AUTHORIZATION'])
  else
    # Switch block arrived, only forward to the verkle backend
    forward_call(vkt_url, data, request.env['HTTP_AUTHORIZATION'])
  end

end

get '/replay_status' do
  last_block ? last_block.to_s : "replay hasn't started yet"
end
