{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
log = require 'iced-logger'
kbmc = require 'keybase-messenger-core'
idg = kbmc.id.generators
C = kbmc.const
{detachsign,burn,KeyManager} = require 'kbpgp'
{unix_time} = require('iced-utils').util
{pack} = require 'purepack'

#=============================================================================

class Streamer

  #---------------

  constructor : ({header, stream}) ->
    @_bufs = []
    @_err = null
    @_buf_total = 0
    if (@_stream = stream)?
      @_stream.on 'end',   () => @_eof = true
      @_stream.on 'error', (e) => [ @_eof, @_error, @err] = [ true, true, e ]
      @_eof = @_error = false
    else
      @_eof = true
      @_error = false
    @push_prefix header

  #---------------

  push_prefix : (buf) ->
    @_bufs.push buf
    @_buf_total += buf.length

  #---------------

  _shift_empty_buffers : () ->
    @_bufs.shift() while @_bufs.length and @_bufs[0].length is 0
    false

  #---------------

  is_eof : () -> (@_buf_total is 0) and @_eof
  data_left : () -> not @is_eof()

  #---------------

  _read_n_from_buffer : (n) ->
    @_shift_empty_buffers()
    ret = if @_bufs.length is 0 then null
    else if @_bufs[0].length < n then @_bufs.shift()
    else 
      ret = @_bufs[0][0...n]
      @_bufs[0] = @_bufs[0][n...]
      ret
    if ret? then @_buf_total -= ret.length
    ret

  #---------------

  _read_at_most_n : (n, cb) ->
    if (ret = @_read_n_from_buffer n)? then # noop
    else if @stream?
      await @stream.once 'readable', defer()
      ret = @stream.read(n)
    cb ret

  #---------------

  read : (n,cb) ->
    tot = 0
    bufs = []
    while @data_left() and tot < n
      await @_read_at_most_n (n - tot), defer buf
      if buf?
        bufs.push buf
        tot += buf.length
    ret = Buffer.concat bufs
    cb err, ret, @is_eof()

#=============================================================================

exports.PostMessageClient = class PostMessageClient extends Base

  #---------

  constructor : ( {cfg, @thread, @from, @km, @msg, @mime_type }) ->
    super { cfg }
    @mime_type or= "text/kstm"

  #---------

  format_header : (cb) ->
    @hdr = {
      mime_type,
      time : unix_time(),
      prev : thread.max_msg_zid
      size : @msg.length
    }
    cb null

  #---------

  init_stream : (cb) -> 
    @stream = [

    ]

  #---------

  sign : (cb) ->
    await detachsign {}, defer err, sig

  #---------

  post : (arg, cb) ->
    log.debug "+ PostMessageClient::authenticate"
    esc = make_esc cb, "PostMessageClient::authenticate"
    await @format_header esc defer()
    await @init_stream esc defer()
    await @sign esc defer()
    await @chunkify esc defer()
    await @post_header esc defer()
    await @post_rest esc defer()
    log.debug "- PostMessageClient::authenticate"
    cb null, @km

  #---------

#=============================================================================
