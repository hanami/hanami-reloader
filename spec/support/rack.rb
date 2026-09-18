# frozen_string_literal: true

module RackHelpers
  # Reads a Rack response body and closes it, as a server would.
  #
  # Closing matters here: the reloader middleware holds its read lock until the body is closed.
  def read(body)
    buffer = +""
    body.each { |chunk| buffer << chunk }
    buffer
  ensure
    body.close if body.respond_to?(:close)
  end
end

RSpec.configure do |config|
  config.include RackHelpers
end
