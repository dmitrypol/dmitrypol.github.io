task :default => [:test]
desc 'test the site'
task :test do
	exec 'script/cibuild'
	#require 'html-proofer'
  	#sh "bundle exec jekyll build"
  	#HTMLProofer.check_directory("./_site").run	
end
