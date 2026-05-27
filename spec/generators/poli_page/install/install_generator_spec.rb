# frozen_string_literal: true

require "rails_helper"
require "rails/generators"
require "rails/generators/test_case"
require "fileutils"
require "tmpdir"

require_relative "../../../../lib/generators/poli_page/install/install_generator"

RSpec.describe PoliPage::Generators::InstallGenerator do
  let(:destination_root) { Dir.mktmpdir("poli_page_install_spec") }

  after { FileUtils.remove_entry(destination_root) if File.directory?(destination_root) }

  def run_generator(args = [])
    described_class.start(args, destination_root: destination_root)
  end

  it "writes config/initializers/poli_page.rb" do
    run_generator
    initializer = File.join(destination_root, "config", "initializers", "poli_page.rb")
    expect(File).to exist(initializer)
  end

  it "includes the api_key fetch from ENV" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    expect(body).to include('ENV.fetch("POLI_PAGE_API_KEY")')
  end

  it "includes the Rails.application.config.poli_page.tap block" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    expect(body).to include("Rails.application.config.poli_page.tap")
  end

  it "comments out base_url, timeout, retries, logger, proxy, ca_file, ca_path, notifications" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    %w[
      c.base_url c.timeout c.max_retries c.retry_delay c.logger
      c.proxy c.ca_file c.ca_path c.notifications c.on_retry c.on_error
    ].each do |line|
      expect(body).to match(/^\s*#\s+#{Regexp.escape(line)}/), "expected #{line} to be commented out"
    end
  end

  it "starts with a frozen_string_literal magic comment" do
    run_generator
    body = File.read(File.join(destination_root, "config", "initializers", "poli_page.rb"))
    expect(body.lines.first).to eq("# frozen_string_literal: true\n")
  end

  context "with an existing initializer" do
    let(:initializer_path) { File.join(destination_root, "config", "initializers", "poli_page.rb") }

    before do
      FileUtils.mkdir_p(File.dirname(initializer_path))
      File.write(initializer_path, "# user edits in here\n")
    end

    # Thor's create_file in interactive mode prompts `[Ynaqdh]` — capital Y
    # is the default. In a real terminal a user pressing <enter> overwrites;
    # in non-TTY mode (CI / tests / scripts) the default Y is also chosen.
    # --skip is the way to refuse.

    it "overwrites with --force" do
      run_generator(["--force"])
      expect(File.read(initializer_path)).to include('ENV.fetch("POLI_PAGE_API_KEY")')
    end

    it "leaves the file untouched with --skip" do
      run_generator(["--skip"])
      expect(File.read(initializer_path)).to start_with("# user edits in here")
    end
  end
end
