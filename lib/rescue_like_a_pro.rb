%w(active_job version).each do |f|
  require "rescue_like_a_pro/#{f}"
end

require "rescue_like_a_pro/railtie" if defined?(::Rails)
