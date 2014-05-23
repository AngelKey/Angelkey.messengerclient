
{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
log = require 'iced-logger'
kbmc = require 'keybase-messenger-core'
idg = kbmc.id.generators
C = kbmc.const
{burn,KeyManager} = require 'kbpgp'
{unix_time} = require('iced-utils').util
{pack} = require 'purepack'

#=============================================================================

exports.AuthorizeClient = class AuthorizeClient extends Base

  #---------

  constructor : ( {cfg, @thread, @user}) ->
    super { cfg }
    @km = null
    @keys = {}

  #---------

  authorize : (cb) ->
    log.debug "+ AuthorizeClient::authorize"
    esc = make_esc cb, "AuthorizeClient::authorize"
    await @init esc defer()
    await @generate esc defer()
    await @sign esc defer()
    await @encrypt defer()
    await @send esc defer()
    log.debug "- AuthorizeClient::authorize"
    cb null, @km

  #---------

  init : (cb) ->
    await @user.get_private_keys defer err, @privkeys
    cb err

  #---------

  sign : (cb) ->
    log.debug "+ sign"
    msg = @cfg.encode_to_buffer {
      version : C.protocol.version.V1
      i : @thread.i  # thread ID
      fingerprint : @km.get_pgp_fingerprint()
      expires : unix_time() + @expire_in
    }
    await burn { msg, signing_key : @privkeys.signing }, defer err, @sig
    log.debug "- sign"
    cb err

  #---------

  encrypt : (cb) ->
    esc = make_esc cb, "AuthorizeClient::encrypt"
    log.debug "+ encrypt"
    await @encrypt_priv esc defer()
    await @encrypt_pub esc defer()
    log.debug "- encrypt"
    cb null

  #---------

  # Encrypt the public temporary verification key with the current shared symmetric
  # session key
  encrypt_pub : (cb) ->
    esc = make_esc cb, "AuthorizeClient::encrypt_pub"
    log.debug "+ encrypt_pub"
    await @km.export_pgp_public {}, esc defer key
    buf = @cfg.encode_to_buffer { key, @sig }
    await @thread.get_cipher().encrypt buf, defer @keys.public
    log.debug "- encrypt_pub"
    cb null

  #---------

  # Encrypt the private temporary verification key with the user's long-lived
  # encryption key
  encrypt_priv : (cb) ->
    esc = make_esc cb, "AuthorizeClient::encrypt_priv"
    log.debug "+ encrypt_priv"
    await @km.export_pgp_private_to_client {}, esc defer tmpkey
    args = 
      msg : tmpkey
      encryption_key : @privkeys.crypt
      signing_key    : @privkeys.signing
      hide : true
    await burn args, esc defer @keys.private
    log.debug "- encrypt_priv"
    cb null

  #---------

  generate : (cb) ->
    esc = make_esc cb, "AuthorizeClient::generate_session_auth_key"
    log.debug "+ generate"
    @expire_in = @cfg.session_auth_key_lifespan()
    args = 
      userid : new Buffer "#{@thread.i.toString('hex')}.#{@user.zid}"
      nbits : @cfg.session_auth_key_bits()
      nsubs : 0
      expire_in : { primary : @expire_in }
    await KeyManager.generate args, esc defer @km
    await @km.sign {}, esc defer()
    log.debug "- generate"
    cb null

  #---------

  send : (cb) ->

    log.debug "+ send"
    arg = 
      endpoint : "thread/authorize"
      method : "POST"
      data:
        i : @thread.i
        user_zid : @user.zid
        token : @user.t
        keys : @keys

    await @request arg, defer err
    log.debug "- send"

    cb err

#=============================================================================
