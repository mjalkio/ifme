# frozen_string_literal: true
class CommentController < ApplicationController
  def create
    comment_id = CommentService.create(params[:comment], current_user)
    response = {
      comment: generate_comments(Comment.where(id: comment_id)).first
    }
    render json: response, status: :ok
  rescue ActiveRecord::RecordInvalid
    bad_request_response
  end

  def delete
    comment = Comment.where(id: params[:comment_id]).first
    return bad_request_response if comment.nil?

    if %w[moment strategy].include?(comment.commentable_type)
      CommentService.delete(comment, current_user)
    elsif comment.commentable_type == 'meeting'
      delete_comment_meeting(comment)
    end
    render json: { id: comment.id }, status: :ok
  rescue TypeError
    bad_request_response
  end

  private

  def bad_request_response
    render json: {}, status: :bad_request
  end

  def remove_meeting_notification!(comment_id)
    CommentNotificationsService.remove(
      comment_id: comment_id,
      model_name: 'meeting'
    )
  end

  def remove_meeting_notification(comment, meeting)
    my_comment = comment.present? && (comment.comment_by == current_user.id)
    return unless (my_comment && meeting.member?(current_user)) ||
                  meeting.led_by?(current_user)

    remove_meeting_notification!(comment.id)
  end

  def delete_comment_meeting(comment)
    meeting_id = comment.commentable_id
    meeting = Meeting.find_by(id: meeting_id)
    remove_meeting_notification(comment, meeting)
  end
end
