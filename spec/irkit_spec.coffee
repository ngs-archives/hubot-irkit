path = require 'path'
Robot = require("hubot/src/robot")
TextMessage = require("hubot/src/message").TextMessage
nock = require 'nock'
chai = require 'chai'
chai.use require 'chai-spies'
{ expect, spy } = chai

describe 'hubot-irkit', ->
  robot = null
  user = null
  adapter = null
  nockScope = null
  beforeEach (done)->
    nock.disableNetConnect()
    nockScope = nock 'https://api.getirkit.com'
    robot = new Robot null, 'mock-adapter', yes, 'TestHubot'
    robot.adapter.on 'connected', ->
      robot.loadFile path.resolve('.', 'src', 'scripts'), 'irkit.coffee'
      hubotScripts = path.resolve 'node_modules', 'hubot', 'src', 'scripts'
      robot.loadFile hubotScripts, 'help.coffee'
      user = robot.brain.userForId '1', {
        name: 'ngs'
        room: '#mocha'
      }
      adapter = robot.adapter
      waitForHelp = ->
        if robot.helpCommands().length > 0
          do done
        else
          setTimeout waitForHelp, 100
      do waitForHelp
    do robot.run

  afterEach ->
    robot.server.close()
    robot.shutdown()
    nock.cleanAll()
    process.removeAllListeners 'uncaughtException'

  describe 'help', ->
    it 'should have 17', (done)->
      expect(robot.helpCommands()).to.have.length 17
      do done

    it 'should parse help', (done)->
      adapter.on 'send', (envelope, strings)->
        ## Prefix bug with parseHelp
        ## https://github.com/github/hubot/pull/712
        try
          expect(strings).to.deep.equal ["""
          TestTestHubot help - Displays all of the help commands that TestHubot knows about.
          TestTestHubot help <query> - Displays all help commands that match <query>.
          TestTestHubot ir list devices - List IRKit device
          TestTestHubot ir list messages for <device_name> - List IR messages
          TestTestHubot ir ls - List IRKit device
          TestTestHubot ir ls msg for <device_name> - List IR messages
          TestTestHubot ir reg <client_token> <client_name> - Register IRKit device
          TestTestHubot ir reg msg <message_name> for <device_name> - Register IR message
          TestTestHubot ir register device <client_token> <client_name> - Register IRKit device
          TestTestHubot ir register message <message_name> for <device_name> - Register IR message
          TestTestHubot ir send <message_name> for <device_name> - Send IR message
          TestTestHubot ir send message <message_name> for <device_name> - Send IR message
          TestTestHubot ir show <client_name> - Show IRKit device
          TestTestHubot ir unreg <client_name> - Unregister IRKit device
          TestTestHubot ir unreg msg <message_name> for <device_name> - Unregister IR message
          TestTestHubot ir unregister device <client_name> - Unregister IRKit device
          TestTestHubot ir unregister message <message_name> for <device_name> - Unregister IR message
          """]
          do done
        catch e
          done e
      adapter.receive new TextMessage user, 'TestHubot help'

  describe 'device', ->

    describe 'register', (done)->
      beforeEach ->
        nockScope = nockScope.post('/1/keys')

      it 'should succeed', (done)->
        nockScope.reply 200, clientkey: 'abcdef', deviceid: '1234'
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Registering client: abcd1234 as foo...'
              'Device: foo is successfully registered.'
            ][count++]]
            if count == 2
              expect(robot.brain.data.irkitDevices).to.deep.equal foo:
                deviceid: '1234'
                clientkey: 'abcdef'
                clienttoken: 'abcd1234'
              do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register device abcd1234 foo'

      it 'should fail when status code != 200', (done)->
        nockScope.reply 503, ''
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Registering client: abcd1234 as foo...'
              'Failed to register device (status:503)'
            ][count++]]
            if count == 2
              expect(robot.brain.data.irkitDevices).to.deep.equal {}
              do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register device abcd1234 foo'

    describe 'unregister', (done)->
      it 'should succeed if device exists', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
        robot.brain.save()
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is successfully unregistered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit unregister device foo'

      it 'should fail if device does not exist', (done)->
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is not registered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit unregister device foo'

    describe 'show', ->
      it 'should response json if device exists', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
        robot.brain.save()
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ["""
            {
              "deviceid": "1234",
              "clientkey": "abcdef",
              "clienttoken": "abcd1234"
            }
            """]
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit show device foo'

      it 'should response error if device does not exist', (done)->
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is not registered.']
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit show device foo'

    describe 'list', ->

      it 'should response device names if device exists', (done)->
        robot.brain.data.irkitDevices = {
          foo:
            deviceid: '1234'
            clientkey: 'abcdef'
            clienttoken: 'abcd1234'
          bar:
            deviceid: '5678'
            clientkey: 'ghijk'
            clienttoken: 'abcd2456'
        }
        robot.brain.save()
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ["""
            foo
            bar
            """]
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit list devices'

      it 'should response no device message if no device exists', (done)->
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['No devices registered.']
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit list devices'

  describe 'message', ->
    describe 'register', ->
      beforeEach ->
        nockScope = nockScope.get '/1/messages?clientkey=abcdef&clear=1'
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
        robot.brain.save()

      it 'should succeed', (done)->
        nockScope.reply 200, message: test: 1
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Waiting for IR message...'
              'Message: poweron for foo is successfully registered.'
            ][count++]]
            do done if count == 2
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register message  poweron  for foo'

      it 'should timeout if no message key', (done)->
        nockScope.reply 200, test: 1
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Waiting for IR message...'
              'Timeout waiting for IR message.'
            ][count++]]
            do done if count == 2
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register message  poweron  for foo'

      it 'should fail if status code != 200', (done)->
        nockScope.reply 503, test: 1
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Waiting for IR message...'
              'Failed to register message (status:503)'
            ][count++]]
            do done if count == 2
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register message  poweron  for foo'

      it 'should response message exists', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweron: {}
        robot.brain.save()
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Message: poweron for foo is already registered.']
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register message  poweron  for foo'

      it 'should response device does not exist', (done)->
        robot.brain.data.irkitDevices = {}
        robot.brain.save()
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is not registered.']
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit register message  poweron  for foo'

    describe 'unregister', ->
      it 'should succeed', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweron: {}
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Message: poweron for foo is successfully unregistered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal foo:
              deviceid: '1234'
              clientkey: 'abcdef'
              clienttoken: 'abcd1234'
              messages: {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit unregister message poweron for foo'

      it 'should response message not registered', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweroff: {}
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Message: poweron for foo is not registered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal foo:
              deviceid: '1234'
              clientkey: 'abcdef'
              clienttoken: 'abcd1234'
              messages:
                poweroff: {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit unregister message poweron for foo'

      it 'should response device not registered', (done)->
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is not registered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit unregister message poweron for foo'

    describe 'list', ->
      it 'should succeed', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweron: {}
            poweroff: {}
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ["""
            poweron
            poweroff
            """]
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit list messages for foo'

      it 'should response device not registered', (done)->
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is not registered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit unregister message poweron for foo'

    describe 'send', ->

      beforeEach ->
        nockScope = nockScope.post '/1/messages'

      it 'should succeed', (done)->
        nockScope.reply 200, 'ok'
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweron: test: 1
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Sending poweron for foo...'
              'Successfully sent message: poweron for foo'
            ][count++]]
            do done if count == 2
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit send message poweron for foo'

      it 'should fail with status code != 200', (done)->
        nockScope.reply 403, 'ok'
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweron: test: 1
        count = 0
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal [[
              'Sending poweron for foo...'
              'Failed to send poweron for foo'
            ][count++]]
            do done if count == 2
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit send message poweron for foo'


      it 'should response message not registered', (done)->
        robot.brain.data.irkitDevices = foo:
          deviceid: '1234'
          clientkey: 'abcdef'
          clienttoken: 'abcd1234'
          messages:
            poweroff: {}
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Message: poweron for foo is not registered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal foo:
              deviceid: '1234'
              clientkey: 'abcdef'
              clienttoken: 'abcd1234'
              messages:
                poweroff: {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit send message poweron for foo'

      it 'should response device not registered', (done)->
        adapter.on 'send', (envelope, strings)->
          try
            expect(strings).to.deep.equal ['Device: foo is not registered.']
            expect(robot.brain.data.irkitDevices).to.deep.equal {}
            do done
          catch e
            done e
        adapter.receive new TextMessage user, 'testhubot irkit send message poweron for foo'


