
{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
{donnie,chris,max} = require '../test/data/users.iced'
{AuthenticateClient} = require './authenticate'
log = require 'iced-logger'
idg = require('keybase-messenger-core').id.generators
{KeyManager} = require 'kbpgp'
{PostMessageClient} = require './post'

#=============================================================================

exports.ThreadClient = class ThreadClient extends Base

  #------------------------------

  constructor : ({cfg, @thread, @me}) ->
    super { cfg }
    @thread_auth_km = null
    @cipher = null
    @max_msg_zid = 0 # the maximum msg zid we got on this thread

  #------------------------------

  # @param {data.Thread} thread  The thread to initialize on the server,
  #   containing the userset that will be involved.
  init_thread : (arg, cb) ->
    esc = make_esc cb, "Client::init_thread"
    scli = new SessionClient { @cfg }
    await scli.establish_session esc defer session_id
    await @thread.gen_init_msg esc defer msg
    msg.session_id = session_id
    args = 
      endpoint : "thread/init"
      method : "POST"
      data : msg
    # We don't need any data back out of the post call, only an indication of success
    # or not.
    @cipher = @thread.get_cipher()
    await @request args, esc defer()
    cb null

  #------------------------------

  get_authenticate_klass : () -> AuthenticateClient
  get_poster_klass : () -> PostMessageClient

  #------------------------------

  authenticate : ({user}, cb) ->
    user or= @me
    klass = @get_authenticate_klass()
    auth = new klass { @thread, user, @cfg }
    await auth.authenticate defer err, @thread_auth_km
    cb err

  #------------------------------

  update_write_token : ({user}, cb) ->
    log.debug "+ update write token for #{user.display_name}"
    msg =
      i : @thread.i
      user_zid : @thread.get_user_zid(user)
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

  #------------------------------

  post_messge : ({msg, mime_type}, cb) ->
    args = { @cfg, from : @me, km : @thread_auth_km, @thread, msg, mime_type }
    klass = @get_poster_klass()
    poster = new klass args
    await poster.post {}, defer err
    cb err

#=============================================================================

unlocker = (raw, cb) ->
  esc = make_esc cb, "Unlocker"
  await KeyManager.import_from_armored_pgp { raw } , esc defer km
  await km.unlock_pgp { passphrase : '' }, esc defer()
  cb null, km

main = (cb) ->
  log.package().env().set_level log.package().DEBUG
  cfg = new Config { port : 3021 }
  user_set = new UserSet { users : [ donnie, chris, max ] }
  thread = new Thread { cfg, user_set, etime : 0 }
  cli = new ThreadClient { cfg, thread, me : donnie }
  esc = make_esc cb, "test"
  msg = "This feels like my element."
  await donnie.unlock_private_key unlocker, esc defer()
  await cli.init_thread {}, esc defer()
  await cli.update_write_token { thread, user : chris }, esc defer()
  await cli.authenticate {}, esc defer()
  await cli.post_message { msg }, esc defer()
  cb null

#=============================================================================

await main defer err
rc = 0
if err?
  log.error err.toString()
  rc = 2
process.exit rc
