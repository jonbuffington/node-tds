{Packet} = require './packet'
{TdsConstants} = require './tds-constants'

###*
Packet for LOGIN7 (0x10). This is the packet sent for initial login

@spec 2.2.6.3
###
class exports.Login7Packet extends Packet
  
  @type: 0x10
  @name: 'LOGIN7'

  constructor: ->
    @type = 0x10
    @name = 'LOGIN7'

  fromBuffer: (stream, context) ->
    length = stream.readUInt32LE()
    stream.assertBytesAvailable length - 4
    @tdsVersion = stream.readUInt32LE()
    @packetSize = stream.readUInt32LE()
    @clientProgramVersion = stream.readUInt32LE()
    @clientProcessId = stream.readUInt32LE()
    @connectionId = stream.readUInt32LE()
    @optionFlags1 = stream.readByte()
    @optionFlags2 = stream.readByte()
    @typeFlags = stream.readByte()
    @optionFlags3 = stream.readByte()
    @clientTimeZone = stream.readUInt32LE()
    @clientLcid = stream.readUInt32LE()
    # function for grabbing strings
    pendingStrings = {}
    getPositionAndLength = (name) ->
      pendingStrings[name] =
        pos: stream.readUInt16LE()
        length: stream.readUInt16LE()
    # grab
    getPositionAndLength 'hostName'
    getPositionAndLength 'userName'
    #TODO: decrypt pass
    getPositionAndLength '.password'
    getPositionAndLength 'appName'
    getPositionAndLength 'serverName'
    getPositionAndLength 'unused'
    getPositionAndLength 'interfaceLibraryName'
    getPositionAndLength 'language'
    getPositionAndLength 'database'
    @clientId = stream.readBytes 6
    getPositionAndLength '.ntlm'
    # ignore length
    stream.skip 4
    # set strings
    for key, value of pendingStrings
      if context.logDebug 
        console.log 'Reading %s at %d of length %d', key, value.pos, value.length
      str = stream.readUcs2String value.length
      if context.logDebug
        console.log 'Read %s: %s', key, str
      if key.charAt 0 isnt '.'
        @[key] = str


  toBuffer: (builder, context) ->
    # validate
    if not @userName? or @userName.length is 0 then throw new Error 'userName not specified'
    if @domain? and @domain.length > 0 then throw new Error 'NTLM not yet supported'
    # length
    @hostName ?= require('os').hostname()
    @password ?= ''
    @appName ?= 'node-tds'
    @serverName ?= ''
    @interfaceLibraryName ?= 'node-tds'
    @language ?= ''
    @database ?= ''
    length = 86 + 2 * (
      @hostName.length +
      @userName.length +
      @password.length +
      @appName.length +
      @serverName.length +
      @interfaceLibraryName.length +
      @language.length +
      @database.length
    ) 
    builder.appendUInt32LE length
    # standard vals
    builder.appendUInt32LE @tdsVersion ? TdsConstants.versionsByVersion['7.1.1']
    builder.appendUInt32LE @packetSize ? 0
    builder.appendUInt32LE @clientProgramVersion ? 7
    builder.appendUInt32LE @clientProcessId ? process.pid
    builder.appendUInt32LE @connectionId ? 0
    builder.appendByte @optionFlags1 ? 0
    builder.appendByte @optionFlags2 ? 0x03
    builder.appendByte @typeFlags ? 0
    builder.appendByte @optionFlags3 ? 0
    builder.appendUInt32LE @clientTimeZone ? 0
    builder.appendUInt32LE @clientLcid ? 0
    # strings
    curPos = 86
    # hostName
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @hostName.length
    curPos += @hostName.length * 2
    # userName
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @userName.length
    curPos += @userName.length * 2
    # password
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @password.length
    curPos += @password.length * 2
    # appName
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @appName.length
    curPos += @appName.length * 2
    # serverName
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @serverName.length
    curPos += @serverName.length * 2
    # unused
    builder.appendUInt16LE curPos
    builder.appendUInt16LE 0
    # interfaceLibraryName
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @interfaceLibraryName.length
    curPos += @interfaceLibraryName.length * 2
    # language
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @language.length
    curPos += @language.length * 2
    # database
    builder.appendUInt16LE curPos
    builder.appendUInt16LE @database.length
    curPos += @database.length * 2
    # clientId
    builder.appendBytes @clientId ? [0, 0, 0, 0, 0, 0]
    # NTLM not supported right now
    builder.appendUInt16LE curPos
    builder.appendUInt16LE 0
    # offset length
    builder.appendUInt32LE length
    # strings
    builder.appendUcs2String @hostName
    builder.appendUcs2String @userName
    builder.appendBuffer @_encryptPass()
    builder.appendUcs2String @appName
    builder.appendUcs2String @serverName
    builder.appendUcs2String @interfaceLibraryName
    builder.appendUcs2String @language
    builder.appendUcs2String @database
    # header
    @insertPacketHeader builder, context

  _encryptPass: ->
    ret = new Buffer @password, 'ucs2'
    for i in [0..ret.length - 1]
      ret[i] = (((ret[i] & 0x0f) << 4) | (ret[i] >> 4)) ^ 0xA5
    ret

