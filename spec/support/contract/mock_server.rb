# frozen_string_literal: true

require "json"
require "socket"

module PoliPage
  module Rails
    module Test
      # Writes the contract's responses as HTTP/1.1 answers.
      module ContractMockResponses
        module_function

        def exhausted
          http(599, { "Content-Type" => "application/json" }, '{"error":"MOCK_EXHAUSTED"}')
        end

        # `response` nil: no response left for this request.
        def serialize(response)
          return exhausted if response.nil?

          headers = response.fetch("headers", {}).dup
          if response.key?("json") && headers.keys.none? { |k| k.casecmp?("content-type") }
            headers["Content-Type"] = "application/json"
          end
          http(response.fetch("status"), headers, body(response))
        end

        def body(response)
          if response.key?("json") then JSON.generate(response["json"])
          elsif response.key?("text") then response["text"]
          elsif response.key?("base64") then response["base64"].unpack1("m")
          else ""
          end
        end

        def http(status, headers, body)
          lines = ["HTTP/1.1 #{status} Mock"]
          headers.each { |name, value| lines << "#{name}: #{value}" }
          lines << "Content-Length: #{body.bytesize}"
          lines << "Connection: close"
          "#{lines.join("\r\n")}\r\n\r\n".b + body.b
        end
      end

      # A local HTTP/1.1 server on 127.0.0.1 for the API contract spec. It
      # answers the case's `responses` in order, one request per connection,
      # and records every request.
      #
      # A response is a Hash in the contract's format: `status` with `headers`
      # and one of `json`, `text` or `base64`, or a `fault`: `drop` closes the
      # socket without a byte, `hang` never answers (until #close). A request
      # with no response left gets `599 MOCK_EXHAUSTED`, so it shows in the
      # recorded requests. The block gets the server's origin and returns the
      # responses (the contract's `{{mock}}` placeholder needs the origin).
      class ContractMockServer
        Recorded = Struct.new(:verb, :target, :headers, keyword_init: true)

        attr_reader :origin

        def initialize
          @requests = []
          @errors = []
          @threads = []
          @lock = Mutex.new
          @released = ConditionVariable.new
          @closed = false
          @server = TCPServer.new("127.0.0.1", 0)
          @origin = "http://127.0.0.1:#{@server.addr[1]}"
          @responses = yield(@origin)
          @acceptor = Thread.new { accept_loop }
        end

        def requests
          @lock.synchronize { @requests.dup }
        end

        # Errors the server hit while answering (a response it cannot write).
        def errors
          @lock.synchronize { @errors.dup }
        end

        # Ends every `hang`, stops accepting and waits for the connections.
        def close
          @lock.synchronize do
            @closed = true
            @released.broadcast
          end
          @server.close
          @acceptor.join(5)
          @lock.synchronize { @threads.dup }.each { |thread| thread.join(5) }
        end

        private

        def accept_loop
          loop do
            socket = @server.accept
            @lock.synchronize { @threads << Thread.new { serve(socket) } }
          end
        rescue IOError, SystemCallError
          nil # the server was closed
        end

        def serve(socket)
          request = read_request(socket)
          answer(socket, record(request)) if request
        rescue IOError, SystemCallError
          nil # the client went away first
        rescue StandardError => e
          @lock.synchronize { @errors << e }
        ensure
          socket.close
        end

        def read_request(socket)
          line = socket.gets("\r\n")
          return nil if line.nil?

          verb, target = line.split
          headers = read_headers(socket)
          length = headers.fetch("content-length", "0").to_i
          socket.read(length) if length.positive?
          Recorded.new(verb: verb, target: target, headers: headers)
        end

        def read_headers(socket)
          headers = {}
          while (header = socket.gets("\r\n")) && header != "\r\n"
            name, value = header.split(":", 2)
            headers[name.strip.downcase] = value.to_s.strip
          end
          headers
        end

        def record(request)
          @lock.synchronize do
            @requests << request
            @responses[@requests.size - 1]
          end
        end

        def answer(socket, response)
          case response&.fetch("fault", nil)
          when nil then socket.write(ContractMockResponses.serialize(response))
          when "drop" then nil # `serve` closes the socket without answering
          when "hang" then @lock.synchronize { @released.wait(@lock) until @closed }
          else raise ArgumentError, "unknown fault #{response["fault"].inspect}"
          end
        end
      end
    end
  end
end
