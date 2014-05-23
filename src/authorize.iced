
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
{unix_time} = require 'iced-utils'
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
    esc = make_esc cb, "AuthorizeClient::authorize"
    await @generate_session_auth_key esc defer()
    await @sign_auth esc defer()
    await @encrypt_session_auth_key defer()
    await @send_request esc defer()
    cb null, @km

  #---------

  sign_auth : (cb) ->
    msg = @cfg.encode_to_buffer {
      version : C.protocol.version.V1
      i : @thread.i  # thread ID
      fingerprint : @km.get_pgp_fingerprint()
      expires : unix_time() + @expire_in
    }
    await burn { msg, signing_key : @km }, defer err, @sig
    cb err

  #---------

  encrypt_session_auth_key : (cb) ->
    esc = make_esc cb, "AuthorizeClient::encrypt_session_auth_key"
    await @encrypt_session_auth_key_priv esc defer()
    await @encrypt_session_auth_key_pub esc defer()
    cb null

  #---------

  encrypt_session_auth_key_pub : (cb) ->
    esc = make_esc cb, "AuthorizeClient::encrypt_session_auth_key_pub"
    await @km.export_pgp_public {}, esc defer key
    buf = @cfg.encode_to_buffer { key, @sig }
    await @thread.get_cipher().encrypt buf, esc defer @keys.public
    cb null

  #---------

  encrypt_session_auth_key_priv : (cb) ->
    esc = make_esc cb, "AuthorizeClient::encrypt_session_auth_key_priv"
    await @km.export_pgp_private_to_client {}, esc defer tmpkey
    await @user.get_signing_key esc defer signing_key
    await burn { msg : tmpkey, signing_key }, esc defer @keys.private
    cb null

  #---------

  generate_session_auth_key : (cb) ->
    esc = make_esc cb, "AuthorizeClient::generate_session_auth_key"
    @expire_in = @cfg.session_auth_key_lifespan()
    args = 
      userid : new Buffer "#{@thread.i.toString('hex')}.#{@user.zid}"
      nbits : @cfg.session_auth_key_bits()
      nsubs : 0
      expire_in : { primary : @expire_in }
    await KeyManager.generate args, esc defer @km
    await @km.sign {}, esc defer()
    cb null

  #---------


  send_request : (cb) ->

    arg = 
      endpoint : "thread/authorize"
      method : "POST"
      data:
        i : @thread.i
        user_zid : @user.zid
        keys : @keys

    await @request arg, defer err
    cb err

  #---------

#=============================================================================
