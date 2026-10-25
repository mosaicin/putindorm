require "json"
require "open3"
require "securerandom"
require "tempfile"

class CodeAgent
  class Error < StandardError; end

  SCOPE_ROOTS = {
    "agent" => %w[ai_agent],
    "store" => %w[app test]
  }.freeze
  MAX_FILES = 12
  MAX_FILE_BYTES = 100_000

  def initialize(root: Rails.root)
    @root = Pathname.new(root).expand_path
    @proposal_dir = @root.join("storage", "code_agent", "proposals")
  end

  def propose(scope:, paths:, task:)
    roots = SCOPE_ROOTS.fetch(scope) { raise Error, "Неизвестная область проекта" }
    paths = Array(paths).map { |path| path.to_s.strip }.reject(&:blank?).uniq
    raise Error, "Укажи хотя бы один файл" if paths.empty?
    raise Error, "Можно указать не более #{MAX_FILES} файлов" if paths.size > MAX_FILES
    raise Error, "Опиши задачу" if task.to_s.strip.blank?

    files = paths.to_h do |path|
      absolute_path = resolve_path(path, roots)
      content = File.file?(absolute_path) ? File.binread(absolute_path) : nil
      raise Error, "Файл слишком большой: #{path}" if content && content.bytesize > MAX_FILE_BYTES
      raise Error, "Файл должен быть текстовым: #{path}" if content&.include?("\0")
      raise Error, "Файл должен быть в кодировке UTF-8: #{path}" if content && !content.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      content&.force_encoding(Encoding::UTF_8)

      [ path, content ]
    end

    generated = generate_files(scope, task.to_s.strip, files, roots)
    raise Error, "ИИ не предложил изменений" if generated.empty?

    proposal = {
      "id" => SecureRandom.hex(16),
      "scope" => scope,
      "created_at" => Time.current.iso8601,
      "status" => "pending",
      "files" => generated.map do |path, content|
        {
          "path" => path,
          "original_sha256" => files[path] && Digest::SHA256.hexdigest(files[path]),
          "content" => content
        }
      end
    }
    save_proposal(proposal)
    proposal.merge("diff" => proposal_diff(proposal))
  end

  def apply(proposal_id)
    raise Error, "Некорректный номер предложения" unless proposal_id.to_s.match?(/\A[0-9a-f]{32}\z/)

    proposal_path = @proposal_dir.join("#{proposal_id}.json")
    raise Error, "Предложение не найдено" unless proposal_path.file?

    proposal = JSON.parse(proposal_path.read)
    raise Error, "Предложение уже применено" unless proposal["status"] == "pending"
    raise Error, "Срок предложения истёк" if Time.iso8601(proposal["created_at"]) < 24.hours.ago

    roots = SCOPE_ROOTS.fetch(proposal["scope"]) { raise Error, "Некорректная область проекта" }
    files = proposal.fetch("files")
    raise Error, "Некорректный файл предложения" if files.empty? || files.size > MAX_FILES

    targets = files.map do |file|
      path = file.fetch("path")
      target = resolve_path(path, roots)
      current_sha256 = File.file?(target) ? Digest::SHA256.file(target).hexdigest : nil
      unless current_sha256 == file["original_sha256"]
        raise Error, "Файл изменился после создания предложения: #{path}"
      end
      content = file.fetch("content")
      raise Error, "Предложенный файл слишком большой: #{path}" if content.bytesize > MAX_FILE_BYTES

      [ path, target, content ]
    end

    temporary_files = targets.map do |_path, target, content|
      FileUtils.mkdir_p(target.dirname)
      tempfile = Tempfile.create([ "code-agent-", ".tmp" ], target.dirname)
      tempfile.binmode
      tempfile.write(content)
      tempfile.flush
      tempfile.close
      [ target, tempfile.path ]
    end
    temporary_files.each { |target, temporary_path| File.rename(temporary_path, target) }

    proposal["status"] = "applied"
    proposal["applied_at"] = Time.current.iso8601
    proposal_path.write(JSON.pretty_generate(proposal))
    proposal
  ensure
    temporary_files&.each { |_target, temporary_path| File.delete(temporary_path) if File.exist?(temporary_path) }
  end

  private

  def generate_files(scope, task, files, roots)
    raise Error, "Установи GROQ_API_KEY в .env или окружении" if ENV["GROQ_API_KEY"].blank?

    input = files.map do |path, content|
      { path: path, content: content, new_file: content.nil? }
    end
    prompt = <<~PROMPT
      Улучши код проекта в области #{scope.inspect}, решая задачу: #{task}
      Изменяй только перечисленные файлы. Не выполняй команды и не добавляй инструкции
      для запуска команд. Верни только JSON такого вида:
      {"files":[{"path":"путь","content":"полное содержимое файла"}]}
      Для новых файлов исходное содержимое null. Сохраняй существующее поведение,
      если задача явно не требует его изменить. Ответ должен содержать полный текст
      каждого изменённого файла, а не diff.

      Файлы:
      #{JSON.pretty_generate(input)}
    PROMPT

    response = AiService.new.ask(prompt, system: "Ты аккуратный ИИ-помощник по разработке. Возвращай только корректный JSON.")
    raise Error, "ИИ не вернул ответ. Проверь API-ключ и доступность провайдера." if response.blank?

    response = response.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "")
    result = JSON.parse(response)
    generated_files = result.fetch("files")
    raise Error, "Некорректный ответ ИИ" unless generated_files.is_a?(Array) && generated_files.size <= MAX_FILES

    requested_paths = files.keys
    generated_files.each_with_object({}) do |file, generated|
      path = file.fetch("path")
      raise Error, "ИИ изменил список разрешённых файлов: #{path}" unless requested_paths.include?(path)
      resolve_path(path, roots)
      content = file.fetch("content")
      raise Error, "ИИ вернул некорректное содержимое файла: #{path}" unless content.is_a?(String)
      raise Error, "ИИ вернул слишком большой файл: #{path}" if content.bytesize > MAX_FILE_BYTES

      generated[path] = content if files[path] != content
    end
  rescue JSON::ParserError, KeyError, TypeError => e
    raise Error, "Не удалось разобрать ответ ИИ: #{e.message}"
  end

  def resolve_path(relative_path, roots)
    path = Pathname.new(relative_path)
    parts = path.each_filename.to_a
    unless !path.absolute? && parts.any? && !parts.any? { |part| %w[. ..].include?(part) } &&
        roots.include?(parts.first) && relative_path !~ /[\\\0]/
      raise Error, "Путь вне разрешённой области: #{relative_path}"
    end

    current = @root
    parts.each do |part|
      current = current.join(part)
      raise Error, "Символические ссылки запрещены: #{relative_path}" if current.symlink?
    end
    raise Error, "Путь выходит за пределы проекта: #{relative_path}" unless current.to_s.start_with?("#{@root}/")

    current
  end

  def proposal_diff(proposal)
    proposal.fetch("files").map do |file|
      path = file.fetch("path")
      current = resolve_path(path, SCOPE_ROOTS.fetch(proposal.fetch("scope")))
      Tempfile.create("code-agent-before") do |before|
        Tempfile.create("code-agent-after") do |after|
          before.write(File.file?(current) ? File.binread(current) : "")
          before.flush
          after.write(file.fetch("content"))
          after.flush
          diff, _error, status = Open3.capture3(
            "diff", "-u", "--label", "a/#{path}", "--label", "b/#{path}", before.path, after.path
          )
          raise Error, "Не удалось построить diff для #{path}" unless [ 0, 1 ].include?(status.exitstatus)

          diff
        end
      end
    end.reject(&:empty?).join("\n")
  end

  def save_proposal(proposal)
    FileUtils.mkdir_p(@proposal_dir)
    @proposal_dir.join("#{proposal.fetch('id')}.json").write(JSON.pretty_generate(proposal))
  end
end
