
{Base} = require './base'
{make_esc} = require 'iced-error'
{checkers} = require 'keybase-bjson-core'
tsec = require 'triplesec'
{WordArray,scrypt} = tsec
{buffer_cmp_ule} = tsec.util
log = require 'iced-logger'
util = require 'util'

#=============================================================================

exports.SessionClient = class SessionClient extends Base

  # cfg contains which server to connect to; might be a Tor address?
  constructor : (args) ->
    super args

  #-------------------------

  _solve_challenge : ({challenge}, cb) ->
    esc = make_esc cb, "SessionClient::solve_challenge"
    log.debug "+ Solving session challenge"

    key = WordArray.from_buffer challenge.token[1]
    {N,r,p,bytes} = challenge.params
    args = {N,r,p, dkLen : bytes }

    target = challenge.params.less_than

    log.debug "| Target is -> #{target.toString('hex')} (with #{bytes} bytes)"

    res = null
    i = 0

    # Make a lot of numbers
    for i in [0...1000000]
      res = new Buffer(4)
      res.writeUInt32BE(i, 0)
      log.debug "| attempt #{i}" if (i % 1024 is 0) and i > 0
      args.salt = WordArray.from_buffer res
      args.key = key.clone()
      await scrypt args, defer out
      b = out.to_buffer()
      break if buffer_cmp_ule(b,target) < 0

    unless res?
      err = new Error "failed to solve the puzzle"

    log.debug "- Solved session challenge @#{i}"
    cb err, res

  #-------------------------

  establish_session : (cb) ->
    esc = make_esc cb, "SessionClient::init_thread"

    log.debug "+ init_session"

    args = 
      endpoint : "session/challenge"
      method : "GET" 
      template: 
        challenge : 
          token : [ checkers.value(1), checkers.buffer(0,100) ] 
          params : 
            bytes : checkers.intval(0,64)
            N : checkers.intval(0,(1<<30))
            p : checkers.intval(1,100)
            r : checkers.intval(1,100)
            less_than : checkers.buffer(0,20)

    # Get a challenge token from the server
    await @request args, esc defer res, json

    challenge = json.body.challenge

    # Now we have to solve the challenge, which will require releasing some C02
    # into the atmosphere
    await @_solve_challenge { challenge }, esc defer solution

    data = { challenge : { token : json.body.challenge.token, solution } }

    args = 
      endpoint : "session/init"
      method : "POST"
      data : data
      template :
        session_id : checkers.buffer(4)

    await @request args, esc defer res, body

    log.debug "| Response from session/init -> #{util.inspect body}"
    log.debug "- init_session"

    cb null, body.body.session_id

#=============================================================================


test = () ->
  {Config} = require './config'
  log.package().env().set_level log.package().DEBUG
  cfg = new Config { port : 3021 }
  sc = new SessionClient { cfg }
  await sc.establish_session defer err
  if err? then throw err
  process.exit 0


