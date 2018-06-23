require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :clients, []
set :master, nil

get '/' do
  return File.read("./index.html") if !request.websocket?
  request.websocket do |ws|
    ws.onopen do
      if settings.master
        ws.send("Hello Client")
        settings.clients << ws
        settings.master.send("client join: " + settings.clients.find_index(ws).to_s)
      else # first one is master
        settings.master = ws
        ws.send("Hello Master")
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
