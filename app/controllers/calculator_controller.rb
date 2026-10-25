class CalculatorController < ApplicationController
  skip_forgery_protection only: :ask

  def index
    @prompt = "Напиши консольный калькулятор на Ruby с операциями +, -, *, /, %, **, обработкой деления на ноль и командой exit."
    @answer = nil
  end

  def ask
    prompt = params[:prompt].to_s.strip

    if prompt.blank?
      return render json: { error: "Пустой промпт" }, status: :bad_request
    end

    answer = AiService.new.ask(prompt)

    if answer
      render json: { answer: answer }
    else
      render json: { error: "ИИ не ответил" }, status: :service_unavailable
    end
  end
end
