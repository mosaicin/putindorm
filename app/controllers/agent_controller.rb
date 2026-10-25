class AgentController < ApplicationController
  def index
  end

  def create
    @proposal = CodeAgent.new.propose(
      scope: params[:scope],
      paths: params[:paths].to_s.lines.map(&:strip),
      task: params[:task]
    )
    render :index
  rescue CodeAgent::Error => e
    @error = e.message
    render :index, status: :unprocessable_entity
  end

  def apply
    CodeAgent.new.apply(params[:id])
    redirect_to agent_path, notice: "Изменения применены. Проверь код и запусти тесты."
  rescue CodeAgent::Error => e
    @error = e.message
    render :index, status: :unprocessable_entity
  end
end
