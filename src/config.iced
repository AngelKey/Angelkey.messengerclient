
#=============================================================================

class Config 

  #-----------------------

  constructor : ({@hostname, @protocol, @port, @api_prefix}) ->

  #-----------------------

  make_url : (args) ->
    pathname = [ "", @api_prefix, args.endpoint ].join("/").replace(/\/+/g, "/")
    { @hostname, @protocol, @port, pathname }

#=============================================================================

