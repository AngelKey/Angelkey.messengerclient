
{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'

#=============================================================================

exports.Client = class Client extends Base

  #------------------------------

  constructor : ({cfg}) ->
    super { cfg }

  #------------------------------

  # @param {data.Thread} thread  The thread to initialize on the server,
  #   containing the userset that will be involved.
  init_thread : ({thread}, cb) ->
    esc = make_esc cb, "Client::init_thread"
    scli = new SessionClient { @cfg }
    await scli.establish_session esc defer session_id
    await thread.gen_init_msg esc defer msg
    msg.session_id = session_id
    args = 
      endpoint : "thread/init"
      method : "POST"
      data : msg
    # We don't need any data back out of the post call, only an indication of success
    # or not.
    await @request args, esc defer()
    cb null

  #------------------------------

#=============================================================================

