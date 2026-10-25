require "test_helper"
require "tmpdir"

class CodeAgentTest < ActiveSupport::TestCase
  test "rejects paths outside the selected project area" do
    agent = CodeAgent.new

    error = assert_raises(CodeAgent::Error) do
      agent.propose(scope: "agent", paths: [ "app/models/product.rb" ], task: "Improve it")
    end

    assert_match "Путь вне разрешённой области", error.message
  end

  test "applies a proposal only after it has been created and only once" do
    Dir.mktmpdir do |directory|
      source = Pathname.new(directory).join("ai_agent/lib/example.rb")
      FileUtils.mkdir_p(source.dirname)
      source.write("puts 'old'\n")
      agent_class = Class.new(CodeAgent) do
        private

        def generate_files(_scope, _task, _files, _roots)
          { "ai_agent/lib/example.rb" => "puts 'new'\n" }
        end
      end
      agent = agent_class.new(root: directory)
      proposal = agent.propose(scope: "agent", paths: [ "ai_agent/lib/example.rb" ], task: "Improve it")

      assert_includes proposal.fetch("diff"), "-puts 'old'"
      assert_includes proposal.fetch("diff"), "+puts 'new'"
      assert_equal "puts 'old'\n", source.read

      agent.apply(proposal.fetch("id"))

      assert_equal "puts 'new'\n", source.read
      assert_raises(CodeAgent::Error) { agent.apply(proposal.fetch("id")) }
    end
  end

  test "rejects traversal paths" do
    agent = CodeAgent.new

    error = assert_raises(CodeAgent::Error) do
      agent.propose(scope: "store", paths: [ "app/../../.env" ], task: "Improve it")
    end

    assert_match "Путь вне разрешённой области", error.message
  end
end
