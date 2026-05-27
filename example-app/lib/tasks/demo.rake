# frozen_string_literal: true

namespace :demo do
  desc "Render the canonical welcome template to ./tmp/welcome.pdf via PoliPage.client.render_to_file"
  task render_to_file: :environment do
    require "fileutils"
    FileUtils.mkdir_p("tmp")
    PoliPage.client.render_to_file(
      "tmp/welcome.pdf",
      project:  "getting-started",
      template: "welcome",
      version:  "1.0.0",
      data:     { name: "rake demo:render_to_file" }
    )
    puts "Wrote tmp/welcome.pdf (#{File.size('tmp/welcome.pdf')} bytes)"
  end
end
