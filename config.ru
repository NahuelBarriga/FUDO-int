# frozen_string_literal: true

require_relative "config/boot"
require_relative "config/routes"
require_relative "lib/json_logger"
require_relative "lib/middleware/request_id"
require_relative "lib/middleware/request_logger"
require_relative "app/http/middleware/error_handler"

logger = JsonLogger.build($stdout, level: ENV.fetch("LOG_LEVEL", "info"))

use Middleware::RequestId
use Http::Middleware::ErrorHandler
use Middleware::RequestLogger
run Routes.build
