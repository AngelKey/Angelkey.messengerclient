
{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
{chris,max} = require '../test/data/users.iced'
log = require 'iced-logger'
idg = require('keybase-messenger-core').id.generators

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

  update_write_token : ({thread, user}, cb) ->
    log.debug "+ update write token for #{user.display_name}"
    msg =
      i : thread.i
      user_zid : thread.get_user_zid(user)
      old_token : user.t
      new_token : idg.write_token()
    args = 
      endpoint : "thread/update_write_token"
      method : "POST"
      data : msg
    await @request args, defer err
    unless err?
      user.t = msg.new_token
    log.debug "- write token update: -> #{err}"
    cb err

#=============================================================================

main = (cb) ->
  log.package().env().set_level log.package().DEBUG
  cfg = new Config { port : 3021 }
  cli = new Client { cfg }
  user_set = new UserSet { users : [ chris, max ] }
  thread = new Thread { cfg, user_set, etime : 0 }
  esc = make_esc cb, "test"
  await cli.init_thread { thread }, esc defer()
  await cli.update_write_token { thread, user : chris }, esc defer()
  cb null

#=============================================================================

await main defer err
rc = 0
if err?
  log.error err.toString()
  rc = 2
process.exit rc
