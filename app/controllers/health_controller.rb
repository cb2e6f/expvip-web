class HealthController < ActionController::Base
  def show
    render json: { status: 'ok' }, status: :ok
  end
end