#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'json'
require 'net/http'
require 'uri'

mpt_url = "https://localhost:8551"
vkt_url = "https://localhost:8552"

# Block number at which the fork happens
FORK_BLOCK = 1000

def forward_call url, data
  uri = URI(url)
  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  req =  Net::HTTP::Post.new(uri.path)
  req.body = data
  req['Content-Type'] = 'application/json'
  https.request(req).body.read
end

converted = false
backlog = []

# This implements a post handler, that redirects
# each RPC call to both the verkle and MPT backends,
# until the transition block is reached.
post '/' do
  data = request.body.read
  command = JSON.parse(data)
  method = command['method']
  parameters = command['params']
  number = parameters['number'].to_i(16)  
  transitionned = number < FORK_BLOCK

  if converted
    # Also send it to the conversion code, if it
    # is transitioned
    forward_call(vkt_url, data) if transitionned
  else
    # Just save the call, to be replayed once the
    # transition has occured.
    backlog << parameters
  end

  forward_call(transitionned ? vkt_url : mpt_url, data)
end

# Indicate that the data has been converted. It will
# replay all saved blocks.
post '/converted' do
  converted = true
  
  backlog.each.with_index do |payload, index|
    forward_call(vkt_url, payload)
  end
  
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
end