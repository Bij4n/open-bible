class CommentsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_comment, only: %i[update destroy]

  def create
    note = Note.visible_to(current_user).find_by(id: params.dig(:comment, :note_id))
    return head :not_found unless note

    parent = note.comments.find_by(id: params.dig(:comment, :parent_id)) if params.dig(:comment, :parent_id).present?

    comment = current_user.comments.build(
      note: note,
      parent: parent,
      body: params.dig(:comment, :body)
    )

    if comment.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("comments_thread_#{note.id}",
                                partial: "comments/comment",
                                locals: { comment: comment }),
            turbo_stream.replace("comment_form_#{note.id}",
                                 partial: "comments/form",
                                 locals: { note: note, parent: nil })
          ]
        end
        format.html { redirect_back fallback_location: root_path }
        format.json { render json: comment_payload(comment), status: :created }
      end
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.html         { head :unprocessable_content }
        format.json         { render json: { errors: comment.errors }, status: :unprocessable_content }
      end
    end
  end

  def update
    if @comment.update(body_param)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            view_context.dom_id(@comment),
            partial: "comments/comment",
            locals: { comment: @comment }
          )
        end
        format.html { head :ok }
        format.json { render json: comment_payload(@comment) }
      end
    else
      head :unprocessable_content
    end
  end

  def destroy
    dom_id_to_remove = view_context.dom_id(@comment)
    @comment.destroy
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id_to_remove) }
      format.html         { head :no_content }
      format.json         { head :no_content }
    end
  end

  private

  def load_comment
    @comment = current_user.comments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end

  def body_param
    params.require(:comment).permit(:body)
  end

  def comment_payload(comment)
    { id: comment.id, body: comment.body, depth: comment.depth, parent_id: comment.parent_id }
  end
end
