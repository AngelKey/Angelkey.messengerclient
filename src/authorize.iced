
{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
log = require 'iced-logger'
idg = require('keybase-messenger-core').id.generators

#=============================================================================

exports.AuthorizeClient = class AuthorizeClient extends Base

  #---------

  constructor : ( {cfg, @id, @tmp_key_generator, @me}) ->
    super { cfg }

  #---------

  authorize : (cb) ->
    await @tmp_key_generator defer err, km
    cb null


  #---------

#=============================================================================
