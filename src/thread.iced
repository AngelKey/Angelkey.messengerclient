
{Base} = require './base'
{make_esc} = require 'iced-error'

#=============================================================================

class Thread extends Base

  # cfg contains which server to connect to; might be a Tor address?
  constructor : (opts) ->
    super opts

  #-------------------------

  init_thread : (cb) ->
    esc = make_esc cb, "Thread::init_thread"

    # Get a challenge token from the server
    await @request { endpoint : "challenge", method : "GET"}, esc defer res, body

    console.log body

    cb null

#=============================================================================

