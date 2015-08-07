require 'sinatra'
require "sinatra/streaming"
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


get '/' do
  erb :index
end

get '/command', provides: 'text/event-stream' do
  
  if `which #{$last_command}`.empty?
    stream do |out|
      out << "data: Command not found\n\n"
      out.close unless out.closed?
    end
    return
  end
 
  PTY.spawn($last_command) do |std_out_err, std_in, pid|
    stream :keep_open do |out|
      begin
        while (line = std_out_err.gets)
          html_line = ""
          
          s = StringScanner.new(line)
          while(!s.eos?)
            if s.scan(/\e\[(3[0-7]|90|1)m/)
              html_line << %{<span class="#{COLOR[s[1]]}">}
            else
              if s.scan(/\e\[(0m|m)/)
                html_line << %{</span>}
              else
                html_line << s.scan(/./m)
              end
            end
          end
        out << "data: #{html_line}\n"
      end
      rescue Errno::EIO
      ensure
        out.close unless out.closed?
        Process.waitpid2 pid rescue nil
        puts "Finished executing '#{$last_command}'"
      end
    end
  end
end

post '/command' do
  $last_command = request.body.read.strip
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
      background-color: #{background}; color: #{color};
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
<div style="top:0; left:0; margin-left:auto; margin-right:auto; text-align:center; width:100%; position:fixed; background-color:#EEE; padding:10px; font-size:20px;">
  <label for="command">Command:</label>
  <input name="command" id="command" style="padding:8px; font-size:20px; max-width:600px; width:100%"></input>
  <input type="button" value="Send" onclick="set_command()" style="font-size:20px; border:none;">
  <input type="button" value="Stop" onclick="stop_command()" style="font-size:20px; border:none;">
  <input type="button" value="Clear" onclick="clear_output()" style="font-size:20px; border:none;">
  
  <label for="size">Font Size:</label>
  <input type="size" id="size" style="padding:8px; font-size:20px; max-width:50px; width:100%;"></input>
  <input type="button" value="Set" onclick="change_font_size()" style="font-size:20px; border:none;">
</div>

<pre style="margin-top:75px; overflow:scroll; margin-left:20px; margin-right:20px; border: 1px solid black; padding:15px;" id='output'></pre>

<script>
  var es = false; 

  function set_command() {
    var data = document.getElementById('command').value;
    var client = new XMLHttpRequest();
    
    client.onreadystatechange = function() {
      if (client.readyState == 4 && client.status == 201) {
        es = new EventSource('/command');
        es.onmessage = function(e) { 
          console.log(e.readyState);
          document.getElementById('output').innerHTML += e.data + "\n";
        };
        es.onerror = function(e) {
          e = e || event, msg = '';

          switch( e.target.readyState ){
            case EventSource.CONNECTING:
              newline();
              es.close();
              return;
            case EventSource.CLOSED:
              console.log("Event source closed");
              return;
          };
        };
      } else {
        if(es.readyState !== 2) {
          es.close();
          newline();
        };
        return;
      }
    }
    
    client.open('POST', '/command', true);
    client.setRequestHeader('Content-Type', 'text/plain');
    client.send(data);

    rm_cursor();
    document.getElementById('output').innerHTML += '$ ' + data + '\n';
  };

  function stop_command() {
    if(es) { 
      console.log("Closing event source"); 
      es.close();
      newline();
    }
  }

  function clear_output() {
    document.getElementById('output').innerHTML = ""
  }

  function change_font_size() {
    var s = document.getElementById('size').value;
    document.getElementById('output').style.fontSize = s;
  }

  function newline(){
    var t = document.getElementById('output').innerHTML;
    if (t.substring(t.length - 1, t.length) !== '>'){
      document.getElementById('output').innerHTML += '>';
    };
  }

  function rm_cursor(){
    var t = document.getElementById('output').innerHTML;
    if (t.substring(t.length - 4, t.length) === '&gt;'){
      document.getElementById('output').innerHTML = t.substring(0, t.length - 4);
    };
  }
</script>

