---
title: "App_version"
date: 2016-07-01
categories:
---

deploy.rb

  # => http://capistranorb.com/documentation/getting-started/flow/
  before :starting, :before_deploy


  desc 'clear logs and tmp'
  task :before_deploy do
    run_locally do
      with rails_env: :production do
        ...
        # => write to file git branch and commit info
        execute "git rev-parse --abbrev-ref HEAD > public/revision.txt"
        execute "git log --oneline -1 >> public/revision.txt"
      end
    end
  end


Internal admin page:

<h3>App Git Branch and Commit</h3>
<%= File.read("#{Rails.root}/public/revision.txt") %>


.gitignore
public/revision.txt

http://stackoverflow.com/questions/12324594/how-to-write-out-the-deployed-git-revision-to-a-file-in-capistrano/38154748#38154748