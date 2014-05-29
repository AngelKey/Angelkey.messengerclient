{SessionClient} = require './session'
{make_esc} = require 'iced-error'
{Base} = require './base'
{Config} = require './config'
{UserSet,Thread} = require './data'
log = require 'iced-logger'
kbmc = require 'keybase-messenger-core'
{checkers} = require 'keybase-bjson-core'
idg = kbmc.id.generators
C = kbmc.const
{hash,detachsign,burn,KeyManager} = require 'kbpgp'
{bufferify,unix_time} = require('iced-utils').util
{pack} = require 'purepack'
util = require 'util'

#=============================================================================

class Streamer

  #---------------

  constructor : ({header, buf, stream}) ->
    @_bufs = []
    @_err = null
    @_buf_total = 0
    if (@_stream = stream)?
      @_stream.on 'end',   () => @_eof = true
      @_stream.on 'error', (e) => [ @_eof, @_error, @_err] = [ true, true, e ]
      @_eof = @_error = false
    else
      @_eof = true
      @_error = false
    @push_prefix header
    @push_prefix buf if buf?

  #---------------

  push_prefix : (buf) ->
    buf = bufferify buf
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
    cb @_err, ret, @is_eof()

#=============================================================================

exports.PostMessageClient = class PostMessageClient extends Base

  @CHUNKSZ : 0x1000
  CHUNKSZ : PostMessageClient.CHUNKSZ

  #---------

  constructor : ( {cfg, @thread, @from, @signing_km, @msg, @stream, @mime_type }) ->
    super { cfg }
    @mime_type or= "text/kstm"

  #---------

  format_header : (cb) ->
    body_size = 0
    if @msg? then    body_size += @msg.length
    if @stream? then body_size += @stream.size
    b2 = pack {
      @mime_type, body_size,
      time : unix_time(),
      prev : @thread.max_msg_zid
    }
    b1 = pack header.length

    # Prepend the header length before the packed header, for ease of unpacking
    @header = Buffer.concat [ b1, b2 ]

    @size = body_size + @header.length
    log.debug "| header: #{util.inspect @header}"
    log.debug "| body_size=#{body_size}; total size=#{@size}"
    cb null

  #---------

  init_stream : (cb) -> 
    @streamer = new Streamer { @header, buf : @msg, stream : @stream?.s }
    @num_chunks = Math.ceil(@size / @CHUNKSZ)
    log.debug "| num_chunks is #{@num_chunks}"
    cb null

  #---------

  post_header : (cb) -> 
    log.debug "+ post_header"
    arg = 
      endpoint : "msg/header"
      method : "POST"
      data : 
        i : @thread.i  # thread ID
        t : @from.t   # write Token
        sender_zid : @from.zid
        etime : 0
        prev_msg_zid : @thread.max_msg_zid
        parent_msg_zid : 0  # for now, all 0
        num_chunks : @num_chunks
      template :
        msg_zid : checkers.nnint
    await @request arg, defer err, res, json
    unless err?
      @msg_zid = json.body.msg_zid
    log.debug "- post_header"
    cb err

  #---------

  post_chunk : (chunk, cb) ->

    log.debug "| encrypting chunk #{@chunk_zid}"
    await @thread.get_cipher().encrypt chunk, defer echunk

    # Sign after encryption
    @hash_streamer.update echunk

    arg = 
      endpoint : "msg/chunk"
      method : "POST"
      data : {
        i : @thread.i,
        t : @from.t,
        sender_zid : @from.zid
        data : echunk,
        @msg_zid, 
        @chunk_zid
      }
    log.debug "| post_chunk #{@chunk_zid}"

    await @request arg, defer err
    @chunk_zid++ unless err?
    cb err

  #---------

  post_body : (cb) ->
    @chunk_zid = 0
    log.debug "+ post_body #{@msg_zid}"
    esc = make_esc cb, "post_body"
    @hash_streamer = hash.streamers.SHA512()
    while @streamer.data_left()
      await @streamer.read @CHUNKSZ, esc defer chunk
      await @post_chunk chunk, esc defer()
    log.debug "- post_body"
    cb null
  #---------

  sign : (cb) ->
    signing_key = @signing_km.find_signing_pgp_key()
    log.debug "| sign message"
    await detachsign { @hash_streamer, signing_key }, defer err, @sig
    cb err

  #---------

  post_sig : (cb) ->
    arg = 
      endpoint : "thread/msg/sig"
      method : "POST"
      data : {
        i : @thread.i
        t : @from.t
        @msg_zid,
        @sig
      }
    log.debug "| post signature"
    await @request arg, defer err
    cb err

  #---------

  post : (arg, cb) ->
    log.debug "+ PostMessageClient::post"
    esc = make_esc cb, "PostMessageClient::post"
    await @format_header esc defer()
    await @init_stream esc defer()
    await @post_header esc defer()
    await @post_body esc defer()
    await @sign esc defer()
    await @post_sig esc defer()
    log.debug "- PostMessageClient::post"
    cb null, @km

  #---------

#=============================================================================
