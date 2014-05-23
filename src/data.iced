
tsec   = require 'triplesec'
{prng} = tsec
{buffer_cmp_ule} = tsec.util
{burn,KeyManager} = require 'kbpgp'
{athrow} = require('iced-utils').util
{E} = require './err'
{make_esc} = require 'iced-error'
kbmc = require 'keybase-messenger-core'
idg = kbmc.id.generators
{Cipher} = kmbc.cipher 

#=============================================================================

H = (x) -> x.toString('hex')

#=============================================================================

strong_random = (n, cb) ->
  await prng.generate n, defer wa
  cb wa.to_buffer()

#=============================================================================

# Things to know about a user
exports.User = class User

  # @param {String} public_key The PGP-armored public keys
  # @param {KeyManager} private_km The unlocked private key, suitable for signing
  constructor : ({@fingerprint, @display_name, @public_key, @inbox_server, @is_me, @private_km}) ->
    @i = null
    @t = null
    @km = null
    @zid = null

  #---------------------

  init : (cb) ->
    await KeyManager.import_from_armored_pgp { raw : @public_key }, defer err, @km
    if not err? and not @fingerprint?
      @fingerprint = @km.get_pgp_fingerprint()
    cb err

  #---------------------

  gen_keys : (cb) ->
    @i or= idg.thread()
    @t or= idg.write_token()
    cb()

  #---------------------

  get_signing_key : (cb) ->
    err = if not @private_km? then new Error "No private key manager available"
    else if @private_km.is_pgp_locked() then new Error "Private key is PGP-locked"
    else if not (ret = @private_km.find_signing_pgp_key())? then new Error "no signing key"
    else null
    cb err, key

  #---------------------

  thread_uid : () -> { @fingerprint, @i }

  #---------------------

  gen_init_msg : ({cfg,payload}, cb) ->
    payload.t = @t
    # Encode JSON object to buffer based on configuration options
    msg = cfg.encode_to_buffer(payload)
    err = null

    unless (encryption_key = @km.find_crypt_pgp_key())?
      err = new Error E.KeyNotFoundError "no enc key for user #{display_name}"
    else
      await burn { encryption_key, msg, opts : { hide : true } }, defer err, ctext

      # The final message sent to the server sends the write token in the clear
      # so the server can authenticate writes from the user.
      msg = { @t, ctext }

    cb err, msg

#=============================================================================

# Users involved in a conversation
exports.UserSet = class UserSet

  constructor : ( {@users}) -> 
    @user_zids = {}

  #---------------------

  sort : () -> @users.sort (a,b) -> buffer_cmp_ule a.fingerprint, b.fingerprint

  #---------------------

  init : (cb) ->
    esc = make_esc cb, "UserSet::init"
    for u in @users
      await u.init esc defer()
    @sort()
    for u,pos in @users
      @user_zids[H(u.fingerprint)] = pos
      u.zid = pos
    cb null

  #---------------------

  get_user_zid: (u) -> @user_zids[H(u.fingerprint)]

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

  constructor : ({@cfg, @user_set, @etime}) ->
    @key = null
    @cipher = null
    @i = null
    @_init_flag = false

  #---------------------

  init : (cb) ->
    esc = make_esc cb, "Thread::init"
    unless @_init_flag
      @_init_flag = true
      await @user_set.init esc defer()
      await @gen_keys defer()
    cb null

  #---------------------

  thread_uids : () -> @user_set.thread_uids()
  get_user_zid : (u) -> @user_set.get_user_zid(u)
  get_cipher : () -> @cipher

  #---------------------

  thread_init_payload : () -> {
    i : @i
    keys : { @k_s, @k_m }
    uids : @thread_uids()
  }
  
  #---------------------

  gen_keys : (cb) ->
    await Cipher.generate_key defer @key
    @cipher = new Cipher { @key }
    @i = idg.thread()
    await @user_set.gen_keys defer()
    cb()

  #---------------------

  gen_init_msg : (cb) ->
    esc = make_esc cb, "gen_init_msg"
    await @init esc defer()
    msg = { @i, users : [], @etime }
    for u in @user_set.users
      payload = @thread_init_payload()
      await u.gen_init_msg { @cfg, payload }, esc defer ctext
      msg.users.push ctext
    cb null, msg

#=============================================================================

