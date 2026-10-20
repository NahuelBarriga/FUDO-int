# frozen_string_literal: true

class Router
  class NotFound < StandardError; end

  class MethodNotAllowed < StandardError
    attr_reader :allowed_methods

    def initialize(allowed_methods)
      @allowed_methods = allowed_methods
      super("Method not allowed")
    end
  end

  Route = Data.define(:verb, :pattern, :app)

  PARAMS_KEY = "router.params"

  def initialize
    @routes = []
  end

  def get(path, app) = add("GET", path, app)
  def post(path, app) = add("POST", path, app)

  def call(env)
    path = env["PATH_INFO"]
    route = find_route(env["REQUEST_METHOD"], path)

    env[PARAMS_KEY] = route.pattern.match(path).named_captures
    route.app.call(env)
  end

  private

  def find_route(verb, path)
    matching = @routes.select { |route| route.pattern.match?(path) }
    raise NotFound if matching.empty?

    route = matching.find { |r| serves(r, verb) }
    raise MethodNotAllowed.new(allowed_methods(matching)) unless route

    route
  end

  def serves(route, verb)
    route.verb == verb || (verb == "HEAD" && route.verb == "GET")
  end

  def allowed_methods(routes)
    verbs = routes.map(&:verb).uniq
    verbs.include?("GET") ? verbs + ["HEAD"] : verbs
  end

  def add(verb, path, app)
    @routes << Route.new(verb: verb, pattern: compile(path), app: app)
  end

  def compile(path)
    pattern = path.split("/").map do |segment|
      segment.start_with?(":") ? "(?<#{segment[1..]}>[^/]+)" : Regexp.escape(segment)
    end.join("/")

    Regexp.new("\\A#{pattern}\\z")
  end
end
