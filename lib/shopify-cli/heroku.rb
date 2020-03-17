module ShopifyCli
  class Heroku
    include Helpers::OS

    DOWNLOAD_URLS = {
      linux: 'https://cli-assets.heroku.com/heroku-linux-x64.tar.gz',
      mac: 'https://cli-assets.heroku.com/heroku-darwin-x64.tar.gz',
      windows: 'https://cli-assets.heroku.com/heroku-win32-x64.tar.gz',
    }

    def initialize(ctx)
      @ctx = ctx
    end

    def app
      return nil if git_remote.nil?
      app = git_remote
      app = app.split('/').last
      app = app.split('.').first
      app
    end

    def authenticate
      result = @ctx.system(heroku_path, 'login')
      raise(ShopifyCli::Abort, "{{x}} Could not authenticate with Heroku") unless result.success?
    end

    def create_new_app
      output, status = @ctx.capture2e(heroku_path, 'create')
      raise(ShopifyCli::Abort, '{{x}} Heroku app could not be created') unless status.success?
      @ctx.puts(output)

      new_remote = output.split("\n").last.split("|").last.strip
      result = @ctx.system('git', 'remote', 'add', 'heroku', new_remote)

      msg = "{{x}} Heroku app created, but couldn’t be set as a git remote"
      raise(ShopifyCli::Abort, msg) unless result.success?
    end

    def deploy(branch_to_deploy)
      result = @ctx.system('git', 'push', '-u', 'heroku', "#{branch_to_deploy}:master")
      raise(ShopifyCli::Abort, "{{x}} Could not deploy to Heroku") unless result.success?
    end

    def download
      return if installed?

      result = @ctx.system('curl', '-o', download_path, DOWNLOAD_URLS[os], chdir: ShopifyCli::ROOT)
      raise(ShopifyCli::Abort, "{{x}} Heroku CLI could not be downloaded") unless result.success?
      raise(ShopifyCli::Abort, "{{x}} Heroku CLI could not be downloaded") unless File.exist?(download_path)
    end

    def install
      return if installed?

      result = @ctx.system('tar', '-xf', download_path, chdir: ShopifyCli::ROOT)
      raise(ShopifyCli::Abort, "{{x}} Could not install Heroku CLI") unless result.success?

      FileUtils.rm(download_path)
    end

    def select_existing_app(app_name)
      result = @ctx.system(heroku_path, 'git:remote', '-a', app_name)

      msg = "{{x}} Heroku app `#{app_name}` could not be selected"
      raise(ShopifyCli::Abort, msg) unless result.success?
    end

    def whoami
      output, status = @ctx.capture2e(heroku_path, 'whoami')
      return output.strip if status.success?
      nil
    end

    private

    def download_filename
      URI.parse(DOWNLOAD_URLS[os]).path.split('/').last
    end

    def download_path
      File.join(ShopifyCli::ROOT, download_filename)
    end

    def git_remote
      output, status = @ctx.capture2e('git', 'remote', 'get-url', 'heroku')
      status.success? ? output : nil
    end

    def heroku_path
      local_path = File.join(ShopifyCli::ROOT, 'heroku', 'bin', 'heroku').to_s
      if File.exist?(local_path)
        local_path
      else
        'heroku'
      end
    end

    def installed?
      _output, status = @ctx.capture2e(heroku_path, '--version')
      status.success?
    rescue
      false
    end
  end
end