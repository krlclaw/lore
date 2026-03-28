# Ensure the repo storage root exists on boot
repo_root = Rails.application.config.lore_repo_root
FileUtils.mkdir_p(repo_root) unless File.directory?(repo_root)
