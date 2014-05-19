
tsec   = require 'triplesec'
{prng} = tsec
{buffer_cmp_ule} = require tsec.util

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

  gen_keys : (cb) ->
    await rando 16, defer @i
    await rando 16, defer @t
    cb()

  thread_uid : () -> { @fingerprint, @i }

  gen_init_msg : (payload, cb) ->
    payload.t = t
    # actually sign
    cb err, enc

#=============================================================================

# Users involved in a conversation
exports.UserSet = class UserSet

  constructor : ( {@users}) -> 
    @sort()

  sort : () -> @users.sort (a,b) -> buffer_cmp_ule a.fingerprint, b.fingerprint

  gen_keys : (cb) ->
    for u in @users
      await u.gen_keys defer()
    cb()

  thread_uids : () -> (u.thread_uid() for u in @users)

#=============================================================================

exports.Thread = class Thread

  constructor : ( {@user_set}) ->
    @k_s = null
    @k_m = null
    @i = null

  thread_uids : () -> @user_set.thread_uids()

  thread_init_payload : () -> {
    i : @i
    keys : { @k_s, @k_m }
    uids : @thread_uids()
  }

  gen_keys : (cb) ->
    await rando 32, defer @k_s
    await rando 32, defer @k_m
    await rando 16, defer @i
    await @user_set.gen_keys defer()
    cb()

#=============================================================================

