
{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
{chris,max} = require '../test/data/users.iced'
log = require 'iced-logger'

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

test = () ->
  log.package().env().set_level log.package().DEBUG
  cfg = new Config { port : 3021 }
  cli = new Client { cfg }
  user_set = new UserSet { users : [ chris, max] }
  thread = new Thread { cfg, user_set }
  await cli.init_thread { thread }, defer err
  rc = 0  
  if err?
    log.error err.toString()
    rc = -2
  process.exit rc

test()