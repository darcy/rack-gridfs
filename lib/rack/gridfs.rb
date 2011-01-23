require 'timeout'
require 'mongo'
require 'uri'

module Rack
  
  class GridFSConnectionError < StandardError ; end
  
  class GridFS

    attr_reader :hostname, :port, :database, :prefix, :db, :user, :password
    
    def initialize(app, options = {})
      options = {
        :hostname => 'localhost',
        :prefix   => 'gridfs',
        :port     => Mongo::Connection::DEFAULT_PORT
      }.merge(options)

      @app        = app
      
      if options[:uri]
        uri = URI.parse(options[:uri])
        raise InvalidScheme.new('must be mongodb') unless uri.scheme == 'mongodb'
        @hostname   = uri.host
        @port       = uri.port
        @database   = uri.path.gsub(/^\//, '')
        @user       = uri.user
        @password   = uri.password
      else
        @hostname   = options[:hostname]
        @port       = options[:port]
        @database   = options[:database]
        @user       = options[:user]
        @password   = options[:password]
      end
      
      @prefix     = options[:prefix]
      @db         = nil

      connect!
    end

    def call(env)
      request = Rack::Request.new(env)
      if request.path_info =~ /^\/#{prefix}\/(.+)-(.+)$/
        gridfs_request($1)
      else
        @app.call(env)
      end
    end

    def gridfs_request(id)
      file = Mongo::Grid.new(db).get(BSON::ObjectId.from_string(id))
      [200, {'Content-Type' => file.content_type}, [file.read]]
    rescue Mongo::GridError, BSON::InvalidObjectId
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    rescue Mongo::GridFileNotFound
      [404, {'Content-Type' => 'text/plain'}, ['File not found.']]
    end
    
    private
    
    def connect!
      Timeout::timeout(5) do
        @db = Mongo::Connection.new(hostname, @port).db(database)
        if @user and @password
          @db.authenticate(@user, @password)
        end
        @db
      end
    rescue Exception => e
      raise Rack::GridFSConnectionError, "Unable to connect to the MongoDB server (#{e.to_s})"
    end
    
  end
    
end
