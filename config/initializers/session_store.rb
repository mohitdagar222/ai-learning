# Rails.application.config.session_store :cookie_store, key: '_waiting_session'

Rails.application.config.session_store :redis_store, key: '_waiting_session'

