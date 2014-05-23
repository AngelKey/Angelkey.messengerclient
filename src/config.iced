
{self_describing_encode} = require 'keybase-bjson-core'

#=============================================================================

exports.Config = class Config 

  #-----------------------

  constructor : ({@hostname, @protocol, @port, @api_prefix, @encoding}) ->
    @hostname or= "localhost"
    @protocol or= "http:"
    @api_prefix or= "/api/1.0"
    @encoding or= "json"


  #-----------------------

  get_encoding : () -> @encoding

  #-----------------------

  encode_to_buffer : (obj) -> self_describing_encode { obj, @encoding }

  #-----------------------

  session_auth_key_bits : () -> 2048
  session_auth_key_lifespan : () -> 60*60*24*365*5

  #-----------------------

  make_url : (args) ->
    ep = [ args.endpoint, @encoding ].join('.')
    pathname = [ "", @api_prefix, ep ].join("/").replace(/\/+/g, "/")
    { @hostname, @protocol, @port, pathname }

#=============================================================================

