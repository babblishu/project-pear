class CustomLogger < Rails::Rack::Logger
  def initialize(app, opts = {})
    @app = app
    @opts = opts
    @opts[:silenced] ||= []
    super
  end

  def call(env)
    if env['X-SILENCE-LOGGER'] || silence_request(env['PATH_INFO'])
      Rails.logger.silence do
        @app.call(env)
      end
    else
      super(env)
    end
  end

  def silence_request(path)
    @opts[:silenced].each do |regexp|
      return true if path =~ regexp
    end
    false
  end
end