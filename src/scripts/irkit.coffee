# Description:
#   Control IRKit the hackable remote controller.
#
# Commands:
#   hubot ir list devices - List IRKit device
#   hubot ir list messages for <device_name> - List IR messages
#   hubot ir ls - List IRKit device
#   hubot ir ls msg for <device_name> - List IR messages
#   hubot ir reg <client_token> <client_name> - Register IRKit device
#   hubot ir reg msg <message_name> for <device_name> - Register IR message
#   hubot ir register device <client_token> <client_name> - Register IRKit device
#   hubot ir register message <message_name> for <device_name> - Register IR message
#   hubot ir send <message_name> for <device_name> - Send IR message
#   hubot ir send message <message_name> for <device_name> - Send IR message
#   hubot ir show <client_name> - Show IRKit device
#   hubot ir unreg <client_name> - Unregister IRKit device
#   hubot ir unreg msg <message_name> for <device_name> - Unregister IR message
#   hubot ir unregister device <client_name> - Unregister IRKit device
#   hubot ir unregister message <message_name> for <device_name> - Unregister IR message

module.exports = (robot) ->

  getDevices = ->
    robot.brain.data.irkitDevices ||= {}

  getDevice = (msg, name, silent = no)->
    devices = getDevices()
    if !(device = devices[name]) && !silent
      msg.send "Device: #{name} is not registered."
    device

  getMessage = (msg, deviceName, messageName, silent = no)->
    if device = getDevice msg, deviceName
      device.messages ||= {}
      if !(message = device.messages[messageName]) && !silent
        msg.send "Message: #{messageName} for #{deviceName} is not registered."
    message

  robot.respond /\s*ir(?:kit)?\s+reg(?:ister)?(?:\s+(?:dev|device))?\s+([^\s]+)\s+([^\s]+)\s*$/i, (msg) ->
    devices = getDevices()
    clienttoken = msg.match[1]
    name = msg.match[2]
    unless /^([0-9a-f]+)$/i.test clienttoken
      msg.send "Invalid client token: #{clienttoken}"
      return
    if getDevice msg, name, yes
      msg.send "Device: #{name} is already registered."
      return
    msg.send "Registering client: #{clienttoken} as #{name}..."
    robot.http('https://api.getirkit.com/1/keys')
      .header('Content-Type', 'application/json')
      .post(JSON.stringify { clienttoken }) (err, res, body) ->
        try json = JSON.parse body
        unless json
          msg.send "Failed to register device (status:#{res.statusCode})"
          return
        {deviceid, clientkey} = json
        devices[name] = { deviceid, clientkey, clienttoken }
        robot.brain.save()
        msg.send "Device: #{name} is successfully registered."

  robot.respond /\s*ir(?:kit)?\s+unreg(?:ister)?(?:\s+(?:dev|device))?\s+([^\s]+)\s*$/i, (msg) ->
    devices = getDevices()
    name = msg.match[1]
    return unless getDevice msg, name
    delete devices[name]
    robot.brain.save()
    msg.send "Device: #{name} is successfully unregistered."

  robot.respond /\s*ir(?:kit)?\s+(?:list|ls)(?:\s+dev(?:ices)?)?\s*$/i, (msg) ->
    devices = getDevices()
    deviceNames = Object.keys devices
    if deviceNames.length > 0
      msg.send "#{ deviceNames.join("\n") }"
    else
      msg.send "No devices registered."

  robot.respond /\s*ir(?:kit)?\s+show\s+(?:device\s+)?([^\s]+)\s*$/i, (msg)->
    devices = getDevices()
    name = msg.match[1]
    if device = getDevice msg, name
      msg.send JSON.stringify device, null, 2

  robot.respond /\s*ir(?:kit)?\s+reg(?:ister)?\s+(?:message|msg)\s+([^\s]+)\s+for\s+([^\s]+)\s*$/i, (msg) ->
    messageName = msg.match[1]
    deviceName = msg.match[2]
    return unless device = getDevice msg, deviceName
    if getMessage msg, deviceName, messageName, yes
      msg.send "Message: #{messageName} for #{deviceName} is already registered."
      return
    msg.send "Waiting for IR message..."
    robot.http("https://api.getirkit.com/1/messages?clientkey=#{device.clientkey}&clear=1")
      .header('Content-Type', 'application/json')
      .get() (err, res, body) ->
        try json = JSON.parse body
        unless message = json?.message
          if res.statusCode == 200
            msg.send "Timeout waiting for IR message."
          else
            msg.send "Failed to register message (status:#{res.statusCode})"
          return
        device.messages[messageName] = message
        robot.brain.save()
        msg.send "Message: #{messageName} for #{deviceName} is successfully registered."

  robot.respond /\s*ir(?:kit)?\s+unreg(?:ister)?\s+(?:message|msg)\s+([^\s]+)\s+for\s+([^\s]+)\s*$/i, (msg) ->
    messageName = msg.match[1]
    deviceName = msg.match[2]
    return unless device = getDevice msg, deviceName
    return unless getMessage msg, deviceName, messageName
    delete device.messages[messageName]
    robot.brain.save()
    msg.send "Message: #{messageName} for #{deviceName} is successfully unregistered."

  robot.respond /\s*ir(?:kit)?\s+(?:list|ls)\s+(?:messages|msg)\s+for\s+([^\s]+)\s*$/i, (msg) ->
    deviceName = msg.match[1]
    return unless device = getDevice msg, deviceName
    messageNames = Object.keys device.messages || {}
    if messageNames.length > 0
      msg.send "#{ messageNames.join("\n") }"
    else
      msg.send "No messages registered for #{deviceName}."

  robot.respond /\s*ir(?:kit)?\s+send\s+(?:(?:message|msg)\s+)?([^\s]+)\s+for\s+([^\s]+)\s*$/i, (msg) ->
    messageName = msg.match[1]
    deviceName = msg.match[2]
    return unless device = getDevice msg, deviceName
    return unless message = getMessage msg, deviceName, messageName
    {clientkey, deviceid} = device
    messageEncoded = encodeURIComponent JSON.stringify message
    msg.send "Sending #{messageName} for #{deviceName}..."
    robot.http('https://api.getirkit.com/1/messages')
      .header('Content-Type', 'application/x-www-form-urlencoded')
      .post("deviceid=#{deviceid}&clientkey=#{clientkey}&message=#{messageEncoded}") (err, res, body) ->
        if res.statusCode == 200
          msg.send "Successfully sent message: #{messageName} for #{deviceName}"
        else
          msg.send "Failed to send #{messageName} for #{deviceName}"
