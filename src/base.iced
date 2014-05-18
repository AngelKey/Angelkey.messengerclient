
{request} = require 'keybase-bjson-client'
{E} = require './err'

#=============================================================================

class Base

  # cfg contains which server to connect to; might be a Tor address?
  constructor : ({@cfg}) ->

  #-------------------------

  request : (args, cb) ->
    args.url = @cfg.make_url args

    http_status = args.http_status or [ 200 ]
    app_status = args.app_status or [ "OK" ]

    await request args, defer err, res, body

    if err? then # noop
    else if not (res.statusCode in http_status)
      err = new E.HttpError "Got reply #{res.statusCode}"
      err.code = res.statusCode
    else if not body.status?.name?
      err = new E.ApplicationError "No body status returned; wanted 'OK'"
    else if not (n = body.status.name) in app_status
      err = new E.ApplicationError "Bad application status: #{n}"
      err.status = body.status

    cb err, res, body

#=============================================================================

