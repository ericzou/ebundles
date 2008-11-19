gem 'git', '>=1.0.0'
require 'git'
require 'git-ext/commit'
require 'net/http'

class GitManager
  attr_reader :git, :target_file
  
  def initialize(target_file)
    @target_file = target_file || ""
    find_working_dir
  end
  
  def remotes
    config_remotes = config.keys.inject([]) do |mem, key|
      if key =~ %r{\Aremote\.(.*)\.url}
        mem << $1
      end
      mem
    end
  end
  
  def github_remotes
    remotes.inject([]) do |mem, remote|
      if repo_for_remote(remote) =~ %r{github\.com}
        mem << remote
      end
      mem
    end
  end
  
  def best_github_remote
    remotes = github_remotes
    selected_remote = 'github' if remotes.include?('github')
    selected_remote ||= 'origin' if remotes.include?('origin')
    selected_remote ||= remotes.first
    raise NotGitHubRepositoryError unless selected_remote
    
    return selected_remote
  end

  def github_url_for_project(github_remote=nil)
    github_remote ||= best_github_remote
    repo = repo_for_remote(github_remote)
    if repo =~ %r{github\.com[:/]([^/]+)/([^.]+)\.git}
      url_head($1, $2)
    end
  end  
  
  def file_to_github_url(github_remote, branch='master', file=nil)
    file ||= target_file
    branch ||= @git.current_branch
    repo = repo_for_remote(github_remote)
    path = file.gsub(working_path, '').gsub(%r{\A/},'')
    if repo =~ %r{github\.com[:/]([^/]+)/([^.]+)\.git}
      user, project = $1, $2
      response = nil
      url_head(user, project, branch) + "/#{path}"
    end
  end
  
  def relative_file(file=nil)
    file ||= target_file
    file = File.expand_path(file).sub(%r{\A#{working_path}/}, '')
  end
  
  # Returns the Git::Object::Commit that adds a +line+
  def find_commit_with_line(line)
    git.log.path(@file).each do |commit|
      return commit if line_in_diff?(commit.diff_parent.to_s, line)
    end
    nil
  end
  
  # Check if the exact line was added in a specific commit (via its parent_diff)
  # TODO - Ensure line is within specific +file+, else might get match within wrong file
  # parent_diff - the results of Git::Object::Commit#parent_diff
  # line - the exact string to match on one line of the diff
  def line_in_diff?(parent_diff, line)
    parent_diff.to_s.split("\n").find { |diff_line| diff_line == "-#{line}" }
  end

  def git?
    git
  end
  
  def working_path
    git.instance_variable_get("@working_directory").path
  end
  
  protected
  def config
    git.config
  end
  
  def find_working_dir
    path = File.dirname(File.expand_path(target_file))
    path_bits = path.split('/') # => ["", "Users", "drnic", "Documents", "ruby", "gems", "newgem", "bin"]
    @git = nil
    while !@git && path_bits.length > 1
      path_bits.pop unless (@git = Git.open(path_bits.join('/')) rescue nil)
    end
    raise NotGitRepositoryError unless @git
  end

  def repo_for_remote(remote)
    config["remote.#{remote}.url"]
  end
  
  def url_head(user, project, branch='')
    branch = "tree/#{branch}" if branch != ''
    project_path = "/#{user}/#{project}/#{branch}"
    project_private?(project_path) ? 
      "https://github.com#{project_path}" : "http://github.com#{project_path}"
  end
  
  def project_private?(project_path)
    response=nil
    Net::HTTP.start('github.com', 80) { |http| response = http.head(project_path) }
    response and response.code.to_i == 302 and response['location'] =~ %r{https:}
  end
  
end