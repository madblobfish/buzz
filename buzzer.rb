require 'sinatra'
require 'sinatra-websocket'

set :server, 'thin'
set :clients, []
set :teams, []
set :master, nil

def client_id(ws)
  settings.clients.find_index(ws).to_s
end
def clients_send(msg)
  EM.next_tick { settings.clients.compact.each{|s| s.send(msg) } }
end

get '/' do
  return File.read("./index.html") if !request.websocket?
  request.websocket do |ws|
    ws.onopen do
      if settings.master
        ws.send("Hello Client")
        settings.clients << ws
        settings.master.send("client join: " + client_id(ws))
      else # first one is master
        settings.master = ws
        ws.send("Hello Master")
      end
    end
    ws.onmessage do |msg|
      if ws == settings.master
        if msg.end_with? " send team"
          if id = msg.to_i(10) && settings.teams[id]
            settings.master.send("team #{settings.teams[id]}: #{id}")
          else
            settings.clients[msg.to_i(10)]&.send("send team")
          end
        else
          clients_send(msg)
        end
      else
        if msg == "buzz"
          settings.master.send("buzz: " + client_id(ws))
        elsif msg =~ /\Ateam: ([0-7])\z/
          team = $1
          settings.master.send("team #{team}: " + client_id(ws))
          settings.teams[client_id(ws).to_i] = team
          7.times{|t| clients_send("team num #{t}: #{settings.teams.count(t.to_s)}")}
        elsif msg =~ /\Aname: ([a-zA-Z0-9 äöü.,_-]+)\z/
          settings.master.send("name #{client_id(ws)}: #{$1}")
        end
      end
    end
    ws.onclose do
      if ws == settings.master
        clients_send("master left")
        puts "master left"
      else
        settings.master.send("client leave: " + client_id(ws))
        settings.clients[client_id(ws).to_i] = nil
        settings.teams[client_id(ws).to_i] = nil
        clients_send("team sub: #{settings.teams[client_id(ws).to_i]}")
      end
    end
  end
end
