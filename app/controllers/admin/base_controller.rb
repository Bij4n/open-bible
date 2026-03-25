module Admin
  # All admin controllers inherit membership gate + a shared admin
  # layout. ApplicationController#ensure_admin heads :not_found for
  # non-admins so the existence of /admin is never leaked.
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :ensure_admin
  end
end
