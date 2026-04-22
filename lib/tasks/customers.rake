namespace :customers do
  desc "Import customers from a Square CSV export. Usage: bin/rails customers:import[path/to/file.csv]"
  task :import, [:path] => :environment do |_task, args|
    path = args[:path]
    abort "Usage: bin/rails customers:import[path/to/file.csv]" if path.blank?
    abort "File not found: #{path}" unless File.exist?(path)

    result = CustomerImporter.new(path).call

    puts "Total rows:   #{result.total}"
    puts "Imported:     #{result.imported.size}"
    puts "Skipped:      #{result.skipped.size}"
    puts "Failed:       #{result.failed.size}"

    if result.skipped.any?
      puts "\nSkipped:"
      result.skipped.each { |s| puts "  row #{s[:row]} #{s[:email] || '(no email)'} — #{s[:reason]}" }
    end

    if result.failed.any?
      puts "\nFailed:"
      result.failed.each { |f| puts "  row #{f[:row]} #{f[:email]} — #{f[:errors].join('; ')}" }
    end

    exit 1 if result.failed.any?
  end
end
