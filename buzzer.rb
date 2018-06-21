require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :clients, []
set :secrets, []
set :master, nil
set :master_secret, nil

get '/:secret?' do
  return File.read("./index.html") if !request.websocket?
  request.websocket do |ws|
    ws.onopen do
      if params['secret']
        puts "OMG #{params['secret']}"
        if params['secret'] == settings.master_secret
          puts "master"
          settings.master = ws
          ws.send("Hello Master")
          EM.next_tick{ settings.clients.compact.each{|s| s.send("master's back") } }
        elsif settings.secrets.include?(params['secret'])
          puts "client"
          idx = settings.secrets.find_index(params['secret'])
          settings.clients[idx] = ws
          ws.send("Hello Client")
        end
      end
      if ws != settings.master && !settings.clients.include?(ws)
        if settings.master
          ws.send("Hello Client")
          settings.clients << ws
          settings.secrets << File.read("/proc/sys/kernel/random/uuid").chop
          ws.send("secret: "+ settings.secrets.last)
          settings.master.send("client join: " + settings.clients.find_index(ws).to_s)
        else # first one is master
          settings.master = ws
          settings.master_secret = "m" + File.read("/proc/sys/kernel/random/uuid").chop
          ws.send("secret: "+ settings.master_secret)
          ws.send("Hello Master")
        end
      end
    end
    ws.onmessage do |msg|
      if ws == settings.master
        if msg.end_with? " send team"
          settings.clients[msg.to_i(10)]&.send("send team")
        else
          EM.next_tick { settings.clients.compact.each{|s| s.send(msg) } }
        end
      else
        if msg == "buzz"
          settings.master.send("buzz: " + settings.clients.find_index(ws).to_s)
        elsif msg =~ /\Ateam: ([0-7])\z/
          settings.master.send("team #{$1}: " + settings.clients.find_index(ws).to_s)
        elsif msg =~ /\Aname: ([a-zA-Z0-9 äöü.,_-]+)\z/
          settings.master.send("name #{settings.clients.find_index(ws).to_s}: #{$1}")
        end
      end
    end
    ws.onclose do
      if ws == settings.master
        EM.next_tick { settings.clients.compact.each{|s| s.send("master left") } }
        puts "master left"
      else
        settings.master.send("client leave: " + settings.clients.find_index(ws).to_s)
        settings.clients[settings.clients.find_index(ws)] = nil
      end
    end
  end
end
