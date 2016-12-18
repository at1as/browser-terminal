# browser-terminal
A session to a localhost terminal accessible from the browser

### Demo

Try it on [Heroku](https://browserterminal.herokuapp.com/)

### Screenshot

![Screenshot](http://at1as.github.io/github_repo_assets/brower-terminal-2.png)

### Usage

* For eventstream and websockets use thin as your webserver
* install dependencies in run.rb
* `$ ruby run.rb`
* navigate browser to 127.0.0.1:4567

### Limitations

* Uses EventSource rather than WebSockets, so STDIN can't be sent to terminal after issuing a command (see screenshot for examples of what can be done)
* Will format for ANSI characters, but won't print special characters (clear terminal, modify existing input, etc)
* This grants *full* access to the terminal. Nefarious users can execute anything they can access in a terminal

