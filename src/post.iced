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

exports.PostMessageClient = class PostMessageClient extends Base

  #---------

  constructor : ( {cfg, @thread, @from, @km, @msg, @mime_type }) ->
    super { cfg }
    @mime_type or= "text/kstm"

  #---------

  post : (arg, cb) ->
    log.debug "+ PostMessageClient::authenticate"
    esc = make_esc cb, "PostMessageClient::authenticate"
    await @sign esc defer()
    await @chunkify esc defer()
    await @post_header esc defer()
    await @post_rest esc defer()
    log.debug "- PostMessageClient::authenticate"
    cb null, @km

  #---------

#=============================================================================
