
{Base} = require './base'
{make_esc} = require 'iced-error'
{checkers} = require 'keybase-bjson-core'

#=============================================================================

class SessionClient extends Base

  # cfg contains which server to connect to; might be a Tor address?
  constructor : (args) ->
    super args

  #-------------------------

  _solve_challenge : ({challenge}, cb) ->
    esc = make_esc cb, "SessionClient::solve_challenge"
    cb new Error "Bailout"

  #-------------------------

  init_session : (cb) ->
    esc = make_esc cb, "SessionClient::init_thread"

    args = 
      endpoint : "session/challenge"
      method : "GET" 
      template: 
        challenge : 
          token : [ checkers.value(1), checkers.buffer(0,100) ] 
          params : { bytes : checkers.intval(0,64), less_than : checkers.buffer(0,20) }

    # Get a challenge token from the server
    await @request args, esc defer res, body

    console.log body

    challenge = body.challenge

    # Now we have to solve the challenge, which will require releasing some C02
    # into the atmosphere
    await @_solve_challenge { challenge }, esc defer solution

    data = { challenge : { token, solution } }

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

