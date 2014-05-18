
#=============================================================================

exports.Config = class Config 

  #-----------------------

  constructor : ({@hostname, @protocol, @port, @api_prefix}) ->
    @hostname or= "localhost"
    @protocol or= "http:"
    @api_prefix or= "/api/1.0"
    @encoding or= "json"

  #-----------------------

  get_encoding : () -> @encoding

  #-----------------------

  make_url : (args) ->
    ep = [ args.endpoint, @encoding ].join('.')
    pathname = [ "", @api_prefix, ep ].join("/").replace(/\/+/g, "/")
    { @hostname, @protocol, @port, pathname }

#=============================================================================

