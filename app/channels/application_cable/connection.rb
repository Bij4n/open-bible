module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    # Devise (via Warden) stashes the authenticated user in the Rack env
    # once the request has passed through middleware. Reject unsigned
    # connections so anonymous visitors can't open a cable.
    def find_verified_user
      verified = env["warden"]&.user
      verified || reject_unauthorized_connection
    end
  end
end
