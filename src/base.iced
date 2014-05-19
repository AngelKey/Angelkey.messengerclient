
{request} = require 'keybase-bjson-client'
{E} = require './err'
{check_template} = require 'keybase-bjson-core'
util = require 'util'

#=============================================================================

exports.Base = class Base

  # cfg contains which server to connect to; might be a Tor address?
  constructor : ({@cfg}) ->

  #-------------------------

  request : (args, cb) ->
    args.url = @cfg.make_url args

    http_status = args.http_status or [ 200 ]
    app_status = args.app_status or [ "OK" ]

    if args.data?
      args.arg = 
        encoding : @cfg.get_encoding()
        data : args.data

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

    if not err? and args.template?
      err = check_template args.template, body.body, "body"
      if err?
        err = new E.ReplyBodyError err.message

    cb err, res, body

#=============================================================================

