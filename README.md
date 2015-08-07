# browser-terminal
A session to a localhost terminal accessible from the browser.

### Screenshot

![Screenshot](http://at1as.github.io/github_repo_assets/browser-terminal.jpg)

### Limitations

* Uses EventSource rather than WebSockets, so STDIN can't be sent to terminal after issuing a command (see screenshot for examples of what can be done)
* Will format for ANSI characters, but won't print special characters (clear terminal, modify existing input, etc)
