#encoding: UTF-8

require 'sinatra'
require 'sinatra/streaming'
require 'tilt/erubis'
require 'thin'
require 'pty'
require 'strscan'

configure do
  $last_command = nil
  COLOR = {
    '1' => 'bold',
    '30' => 'black',
    '31' => 'red',
    '32' => 'green',
    '33' => 'yellow',
    '34' => 'blue',
    '35' => 'magenta',
    '36' => 'cyan',
    '37' => 'white',
    '90' => 'grey'
  }
end

helpers do
  include Rack::Utils
  alias_method :safe_text, :escape_html
end

get '/' do
  erb :index
end

get '/command', provides: 'text/event-stream' do
 
  last_command = $last_command
  flagless_command = $flagless_command
 
  begin  
    PTY.spawn(last_command) do |std_out_err, std_in, pid|
      stream :keep_open do |out|
        begin

          # Need to send data every 20 seconds to keep stream open
          # n.b. Browsers on windows often timeout with less than 5 second interval
          keep_alive = EventMachine::PeriodicTimer.new(20) do
            out << "data: ##keepalive##\n\n" rescue nil 
          end

          while (line = std_out_err.gets.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '') rescue nil)
            html_line = ""
           
            s = StringScanner.new(line)
            while(!s.eos?)
              if s.scan(/\e\[(3[0-7]|90|1)m/)
                html_line << %{<span class="#{COLOR[s[1]]}">}
              else
                if s.scan(/\e\[(0m|m)/)
                  html_line << %{</span>}
                else
                  html_line << safe_text(s.scan(/./m))
                end
              end
            end
            out << "data: #{html_line}\n\n"
          end
        rescue Errno::EIO
        ensure
          keep_alive.cancel rescue nil
          out.close unless out.closed?
          Process.waitpid2 pid rescue nil
          puts "Finished executing '#{last_command}'\n"
        end
      end
    end
  rescue Errno::ENOENT # Command Not Found
    stream do |out|
      out << "data: Command not found\n\n"
      out.close unless out.closed?
    end
  end
end

post '/command' do
  $last_command = request.body.read.strip
  $flagless_command = $last_command.split("\s").first
  201
end

__END__

@@ layout
<html>
  <head>
    <title>Web Terminal</title> 
    <meta charset="utf-8" />
  <style>
    body {
      background-color: #F7F7F7;
      font-family: Arial;
    }
    .bold {
      font-weight: bold;
    }
    .black {
      color: black;
    }
    .red {
      color: red;
    }
    .green {
      color: green;
    }
    .yellow {
      color: yellow;
    }
    .blue {
      color: blue;
    }
    .magenta {
      color: magenta;
    }
    .cyan {
      color: cyan;
    }
    .white {
      color: white;
    }
    .grey {
      color: grey;
    }
  </style>
  </head>

  <body><%= yield %></body>
</html>


@@ index
<div style="top:0; left:0; margin-left:auto; margin-right:auto; text-align:center; width:100%; position:fixed; background-color:#EEE; padding:10px; font-size:20px; border-bottom: 1px solid #777;">
  <input name="command" id="command" placeholder="Terminal Command" style="padding:8px; font-size:20px; max-width:600px; width:100%"></input>
  <input type="button" value="Send" onclick="set_command()" style="font-size:20px; border:none; background-color:#428bca; padding-top:8px; padding-bottom:8px; border-radius:3px; color:white">
  <input type="button" value="Stop" onclick="stop_command()" style="font-size:20px; border:none; background-color:#428bca; padding-top:8px; padding-bottom:8px; border-radius:3px; color:white">
  <input type="button" value="Clear" onclick="clear_output()" style="font-size:20px; border:none; padding-top:8px; padding-bottom:8px; border-radius:3px; color:white; background-color:black">
  
  <input type="size" id="size" placeholder="Font Size" style="padding:8px; font-size:18px; max-width:105px; width:100%; margin-left:10px"></input>
  <input type="button" value="Set" onclick="change_font_size()" style="font-size:20px; border:none; padding-top:8px; padding-bottom:8px; border-radius:3px; color:white; background-color:black">
</div>

<pre style="margin-top:75px; overflow:scroll; margin-left:20px; margin-right:20px; border: 1px solid black; padding:15px; border-radius:4px; background-color:black; color:white; padding-top:8px; padding-bottom:8px; border-radius:3px" id='output'></pre>

<script>
  var es = false; 

  function set_command() {
    var data = document.getElementById('command').value;
    var client = new XMLHttpRequest();
    
    clear_input();
    
    client.onreadystatechange = function() {
      if (client.readyState == 4 && client.status == 201) {
        es = new EventSource('/command');
        rm_cursor();
        
        es.onmessage = function(e) { 
          if (e.data !== "##keepalive##") {
            document.getElementById('output').innerHTML += e.data + "\n";
            window.scrollTo(0, document.body.scrollHeight);
          }
        }
        es.onerror = function(e) {
          e = e || event, msg = '';

          switch( e.target.readyState ){
            case EventSource.CONNECTING: // Stream Closed
              newline();
              es.close();
              return;
            case EventSource.CLOSED:
              console.log("Event source closed");
              return;
          }
          //rm_cursor();
        }
      } else {
        if(es.readyState !== 2) {
          try {
            es.close();
          } catch(e) {
            // socket already closed
          }
          newline();
        }
        return;
      }
    }
    
    client.open('POST', '/command', true);
    client.setRequestHeader('Content-Type', 'text/plain');
    client.send(data);

    rm_cursor();
    document.getElementById('output').innerHTML += '<span style="color:red">\n$</span> ' + data + '\n';

    window.scrollTo(0, document.body.scrollHeight);
  }

  function stop_command() {
    if(es) { 
      console.log("Closing event source"); 
      es.close();
      newline();
    }
  }

  function clear_output() {
    document.getElementById('output').innerHTML = "";
  }
  
  function clear_input() {
    document.getElementById('command').value = ""
  }

  function change_font_size() {
    var s = document.getElementById('size').value;
    document.getElementById('output').style.fontSize = s;
  }

  function newline(){
    // Append '>' to new line to indicate command execution is complete
    var t = document.getElementById('output').innerHTML;
    if (t.substring(t.length - 1, t.length) !== '>'){
      document.getElementById('output').innerHTML += '>';
    }
    window.scrollTo(0, document.body.scrollHeight);
  }

  function rm_cursor(){
    // Remove '>' cursor from line
    var t = document.getElementById('output').innerHTML;
    if (t.substring(t.length - 4, t.length) === '&gt;'){
      document.getElementById('output').innerHTML = t.substring(0, t.length - 4);
    }
  }

  window.onkeyup = function(e) {
    // Listen for 'Enter' keypress is cursor is in command field and send request
    var key = e.keyCode ? e.keyCode : e.which;
    var cmd_field = document.getElementById('command');

    if (key == 13 && cmd_field === document.activeElement && cmd_field.value !== "") {
      set_command(); 
    }
  }

</script>

