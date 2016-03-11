task :default => [:test]
desc 'test the site'
task :test do
	exec 'script/cibuild'
end
