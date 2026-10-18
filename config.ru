# frozen_string_literal: true

require_relative "config/boot"
require_relative "config/routes"
require_relative "app/http/middleware/error_handler"

use Http::Middleware::ErrorHandler
run Routes.build
