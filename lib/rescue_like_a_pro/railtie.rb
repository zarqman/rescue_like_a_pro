module RescueLikeAPro
  class Railtie < ::Rails::Railtie

    ActiveSupport.on_load(:active_job) do
      prepend RescueLikeAPro::ActiveJob
    end

  end
end
