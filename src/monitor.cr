require "http"
require "tallboy"
require "clim"
require "wafalyzer"
require "colorize"

module Monitor
  VERSION = "0.1.0"

  class Run < Clim
    PROBLOMATIC_STATUS_CODES = {
      401 => "Unauthorized - The request requires user authentication.",
      403 => "Forbidden - The server understood the request, but is refusing to fulfill it.",
      429 => "Too Many Requests - This means we are being rate limited",
      500 => "Internal Server Error - This means something is wrong with the server",
      502 => "Bad Gateway - This means something is wrong with the server",
      503 => "Service Unavailable - This means something is wrong with the server",
      504 => "Gateway Timeout - This means something is wrong with the server",
    }

    main do
      desc <<-DESC
        ██████╗ ██████╗ ██╗ ██████╗ ██╗  ██╗████████╗███████╗███████╗ ██████╗              ███╗   ███╗ ██████╗ ███╗   ██╗██╗████████╗ ██████╗ ██████╗
        ██╔══██╗██╔══██╗██║██╔════╝ ██║  ██║╚══██╔══╝██╔════╝██╔════╝██╔════╝              ████╗ ████║██╔═══██╗████╗  ██║██║╚══██╔══╝██╔═══██╗██╔══██╗
        ██████╔╝██████╔╝██║██║  ███╗███████║   ██║   ███████╗█████╗  ██║         █████╗    ██╔████╔██║██║   ██║██╔██╗ ██║██║   ██║   ██║   ██║██████╔╝
        ██╔══██╗██╔══██╗██║██║   ██║██╔══██║   ██║   ╚════██║██╔══╝  ██║         ╚════╝    ██║╚██╔╝██║██║   ██║██║╚██╗██║██║   ██║   ██║   ██║██╔══██╗
        ██████╔╝██║  ██║██║╚██████╔╝██║  ██║   ██║   ███████║███████╗╚██████╗              ██║ ╚═╝ ██║╚██████╔╝██║ ╚████║██║   ██║   ╚██████╔╝██║  ██║
        ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚══════╝ ╚═════╝              ╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝
        DESC
      usage "monitor --url <url>"
      version "Version 0.1.0"
      option "-u URL", "--url=URL", type: String, desc: "Target URL.", required: true
      option "-c CONCURRENCY", "--concurrency=CONCURRENCY", type: Int32, desc: "Number of concurrent requests to make.", default: 10
      option "-t TOTAL_REQUESTS", "--total-requests=TOTAL_REQUESTS", type: Int32, desc: "Total number of requests to make.", default: 1000

      @files_created : Atomic(Int32) = Atomic(Int32).new(0)

      run do |opts, args|
        uri = URI.parse(opts.url)
        Dir.mkdir("#{Dir.tempdir}/#{uri.host}") unless Dir.exists?("#{Dir.tempdir}/#{uri.host}")
        puts "Debug files will be saved to #{Dir.tempdir}/#{uri.host}"
        sleep 3.seconds
        unless uri.host && uri.scheme
          raise "Error: URL Is Malformed"
        end
        response_channel = Channel(Int32 | Exception).new(opts.total_requests)
        uri_channel = Channel(URI).new(opts.total_requests)
        opts.concurrency.times do
          spawn do
            request_handlers(uri_channel, response_channel)
          end
        end
        spawn do
          opts.total_requests.times do
            uri_channel.send(uri)
          end
        end

        responses = Hash(String | Int32, Int32).new(0)
        exception_messages = Hash(String, String).new
        wafs = Array(Wafalyzer::Waf).new
        begin
          wafs = Wafalyzer.detect(url: uri.to_s)
        rescue Exception
        end

        opts.total_requests.times do |i|
          response = response_channel.receive
          print "\r#{i + 1}/#{opts.total_requests} requests complete"
          if response.is_a?(Exception)
            unless exception_messages[response]?
              exception_messages[response.class.to_s] = response.message.to_s
            end
            responses[response.class.to_s] += 1
          else
            responses[response] += 1
          end
        end
        table = Tallboy.table do
          columns do
            add "Responses"
            add "Count"
            add "Description"
          end
          header
          responses.each do |code, count|
            case code
            when Int32
              row [code, count, PROBLOMATIC_STATUS_CODES[code]? || "OK"]
            when String
              row [code, count, exception_messages[code]]
            end
          end
        end
        puts table
        puts "Debug Files Created: #{@files_created.get}" if @files_created.get > 0
        puts "WAFs detected: #{wafs.map(&.to_s).join(", ")}".colorize(:red).mode(:bold) unless wafs.empty?
      end

      def request_handlers(uri_channel : Channel(URI), response_channel : Channel(Int32 | Exception))
        loop do
          uri = uri_channel.receive
          response = HTTP::Client.get(uri.to_s)
          unless response.status.success?
            File.tempfile(prefix: "#{uri.host}", suffix: ".html", dir: "#{Dir.tempdir}/#{uri.host}") do |file|
              file.print(response.body)
            end
            @files_created.add(1)
          end
          response_channel.send(response.status_code)
        rescue e : Exception
          response_channel.send(e)
        end
      end
    end
  end
end

Monitor::Run.start(ARGV)
