
tsec   = require 'triplesec'
{prng} = tsec
{buffer_cmp_ule} = require tsec.util
{KeyManager} = require 'kbpgp'
{athrow} = require('iced-utils').util
{E} = require './err'

#=============================================================================

rando : (n, cb) ->
  await prng.generate n, defer wa
  cb wa.to_buffer()

#=============================================================================

# Things to know about a user
exports.User = class User

  constructor : ({@fingerprint, @display_name, @public_key, @inbox_server, @is_me}) ->
    @i = null
    @t = null

  #---------------------

  gen_keys : (cb) ->
    await rando 16, defer @i
    await rando 16, defer @t
    cb()

  #---------------------

  thread_uid : () -> { @fingerprint, @i }

  #---------------------

  gen_init_msg : ({cfg,payload}, cb) ->
    payload.t = @t
    # Encode JSON object to buffer based on configuration options
    msg = @cfg.encode_to_buffer(payload)

    esc = make_esc cb, "User::gen_init_msg"

    await KeyManager.import_from_armored_pgp { raw : @public_key }, esc defer km
    unless (encryption_key = km.find_crypt_pgp_key())?
      athrow (new Error E.KeyNotFoundError "no enc key for user #{display_name}"), esc defer()
    await burn { encryption_key, msg, opts : { hide : true } }, esc defer, ctext

    # All done...
    cb null, ctext

#=============================================================================

# Users involved in a conversation
exports.UserSet = class UserSet

  constructor : ( {@users}) -> 
    @sort()

  #---------------------

  sort : () -> @users.sort (a,b) -> buffer_cmp_ule a.fingerprint, b.fingerprint

  #---------------------

  gen_keys : (cb) ->
    for u in @users
      await u.gen_keys defer()
    cb()

  #---------------------

  thread_uids : () -> (u.thread_uid() for u in @users)

  #---------------------

  get_users : () -> @users

#=============================================================================

exports.Thread = class Thread

  constructor : ({@cfg, @user_set}) ->
    @k_s = null
    @k_m = null
    @i = null

  #---------------------

  thread_uids : () -> @user_set.thread_uids()

  #---------------------

  thread_init_payload : () -> {
    i : @i
    keys : { @k_s, @k_m }
    uids : @thread_uids()
  }
  
  #---------------------

  gen_keys : (cb) ->
    await rando 32, defer @k_s
    await rando 32, defer @k_m
    await rando 16, defer @i
    await @user_set.gen_keys defer()
    cb()

  #---------------------

  gen_init_msg : (cb) ->
    msg = { @i, users : [] }
    esc = make_esc cb, "gen_init_msg"
    for u in @user_set.users()
      payload = @thread_init_payload()
      await u.gen_init_msg { @cfg, payload }, esc defer ctext
      msg.users.push ctext
    cb null, msg

#=============================================================================

