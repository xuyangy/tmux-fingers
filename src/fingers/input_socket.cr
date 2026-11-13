require "file_utils"
require "socket"
require "./dirs"

module Fingers
  class InputSocket
    @path : String

    def initialize(path = Fingers::Dirs::SOCKET_PATH.to_s)
      @path = path
    end

    # Starts accepting connections. Messages sent before #on_input is called
    # wait in the socket's backlog.
    def listen
      server
    end

    def on_input
      loop do
        socket = server.accept
        message = socket.gets

        yield (message || "")
      end
    end

    def send_message(cmd)
      socket = UNIXSocket.new(path)
      socket.puts(cmd)
      socket.close
    end

    def close
      server.close
      remove_socket_file
    end

    private getter :path

    def server
      @server ||= begin
        remove_socket_file
        UNIXServer.new(path)
      end
    end

    def remove_socket_file
      FileUtils.rm_rf(path)
    end
  end
end
