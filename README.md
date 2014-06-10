hubot-irkit
===========

![](http://ja.ngs.io/images/2014-06-09-hubot-irkit/picture.jpg)

A [Hubot] script to control [IRKit] the hackable remote controller.

```
me > hubot ir register device XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX office-amp
hubot > Registering client: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX as office-amp...
hubot > Device: office-amp is successfully registered.
me > hubot ir register message poweron for office-amp
hubot > Waiting for IR message...
hubot > Message: poweron for office-amp is successfully registered.
me > hubot ir send message poweron for office-amp
hubot > Sending poweron for office-amp..
hubot > Successfully sent message: poweron for office-amp
```

Commands
--------

```
hubot ir register device <client_token> <client_name> - Register IRKit device
hubot ir unregister device <client_name> - Unregister IRKit device
hubot ir show <client_name> - Show IRKit device
hubot ir list devices - List IRKit device
hubot ir register message <message_name> for <device_name> - Register IR message
hubot ir unregister message <message_name> for <device_name> - Unregister IR message
hubot ir list messages for <device_name> - List IR messages
hubot ir send message <message_name> for <device_name> - Send IR message
```

Installation
------------

1. Add `hubot-irkit` to dependencies.

  ```bash
  npm install --save hubot-irkit
  ```

2. Update `external-scripts.json`

  ```json
  ["hubot-irkit"]
  ```

Setup
-----

### 1. Purchase and setup your IRKit

If you don't have one yet, purchase IRKit from [Amazon] Affiliate link :yen:.

Set it up following the official instruction and connect to your local network (may be contained in the package).

### 2. Retrieve your client token

As descried in the [official document], retrieve your instance name with `dns-sd` command.

```bash
dns-sd -B _irkit._tcp
```

You may get the response like this

```
Browsing for _irkit._tcp
DATE: ---Mon 09 Jun 2014---
 1:22:43.931  ...STARTING...
Timestamp     A/R    Flags  if Domain               Service Type         Instance Name
 1:22:44.104  Add        2   4 local.               _irkit._tcp.         irkita1EC
 1:22:44.105  Add        2   4 local.               _irkit._tcp.         iRKit928E
```

Pick an instance name and append `.local` suffix and inspect the address.

```bash
dns-sd -G v4 irkita1EC.local
```

```
DATE: ---Mon 09 Jun 2014---
 1:24:14.248  ...STARTING...
Timestamp     A/R Flags if Hostname                               Address                                      TTL
 1:24:14.524  Add     2  4 irkita1ec.local.                       192.168.1.29                                 10
```

Then request client token.

```bash
curl -i -XPOST http://192.168.1.29/keys
```

```
HTTP/1.0 200 OK
Access-Control-Allow-Origin: *
Server: IRKit/1.3.6.0.g96a9b88
Content-Type: text/plain

{"clienttoken":"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"}
```

### 3. Register your IRKit device

Finally you can register your IRKit device to your Hobot's brain.

```
hubot ir register device XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX office-amp
```

Author
------

[Atsushi Nagase]

License
-------

[MIT License]


[Hubot]: http://hubot.github.com/
[IRKit]: http://getirkit.com/en/
[Amazon]: http://www.amazon.co.jp/gp/product/B00H91KK26/ref=as_li_ss_tl?ie=UTF8&camp=247&creative=7399&creativeASIN=B00H91KK26&linkCode=as2&tag=atsushnagased-22
[official document]: http://getirkit.com/en/#toc_5
[Hubot]: https://hubot.github.com/
[Atsushi Nagase]: http://ngs.io/
[MIT License]: LICENSE
