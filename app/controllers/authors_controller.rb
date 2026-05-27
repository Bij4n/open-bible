class AuthorsController < ApplicationController
  def show
    @author = User.find(params[:id])
    @notes  = @author.notes.public_note.order(updated_at: :desc)
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end
