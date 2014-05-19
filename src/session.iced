
{Base} = require './base'
{make_esc} = require 'iced-error'
{checkers} = require 'keybase-bjson-core'
tsec = require 'triplesec'
{WordArray,scrypt} = tsec
{buffer_cmp_ule} = tsec.util

#=============================================================================

class SessionClient extends Base

  # cfg contains which server to connect to; might be a Tor address?
  constructor : (args) ->
    super args

  #-------------------------

  _solve_challenge : ({challenge}, cb) ->
    esc = make_esc cb, "SessionClient::solve_challenge"

    key = WordArray.from_buffer challenge.token[1]
    {N,r,p,bytes} = challenge.params
    args = {N,r,p, dkLen : bytes }

    target = challenge.params.less_than

    res = null

    # Make a lot of numbers
    for i in [0...1000000]
      res = new Buffer(4)
      res.writeUInt32BE(i, 0)
      args.salt = WordArray.from_buffer res
      args.key = key.clone()
      await scrypt args, defer out
      b = out.to_buffer()
      break if buffer_cmp_ule(b,target) < 0

    unless res?
      err = new Error "failed to solve the puzzle"

    cb err, res

  #-------------------------

  init_session : (cb) ->
    esc = make_esc cb, "SessionClient::init_thread"

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

    await @request { endpoint : "session/init" , method : "POST", data }, esc defer res, body

    console.log body

    cb null

#=============================================================================


test = () ->
  {Config} = require './config'
  cfg = new Config { port : 3021 }
  thread = new SessionClient { cfg }
  await thread.init_session defer err
  if err? then throw err
  process.exit 0

test()

