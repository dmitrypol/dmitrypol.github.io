---
title: "Redis Workflow Engine"
date: 2017-12-16
categories: redis
---

When we need to scale applications Redis can be a great tool.  Slow tasks such as sending emails can be done via background process which is an easy win for user experience.  In many situations we do not care about the order in which different jobs are executed.  

* TOC
{:toc}

But sometimes we do.  What if we are working on an application that periodically runs data import processes.  Data comes in from various sources in different formats.  We build several classes (using [Ruby on Rails ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html)) to appropriately handle the imports.  Then we generate report summarizing the data.

{% highlight ruby %}
class ImportCsvJob < ApplicationJob
  # validate data and create records in our DB
end
class ImportXmlJob < ApplicationJob
  # similar process here
end
class GenReportJob < ApplicationJob
end
{% endhighlight %}

One option is to schedule the `GenReportJob` to run well after all the import jobs.  But that may lead to problems when the individual imports take longer than expected.  Or we need to start running imports more frequently.  Now we are generating reports based on incomplete data and customers are upset.  

### Simple workflow

What we need is a workflow process that will run `GenReportJob` after ALL `import` jobs complete successfully.  [gush](https://github.com/chaps-io/gush) library can help with that.  

{% highlight ruby %}
# app/workflows/import_workflow.rb
class ImportWorkflow < Gush::Workflow
  def configure
    run ImportCsvJob
    run ImportXmlJob
    run GenReportJob, after: [ImportCsvJob, ImportXmlJob]
  end
end
# app/jobs/
class GenReportJob < Gush::Job
end
class ImportCsvJob < Gush::Job
end
class ImportXmlJob < Gush::Job
end
{% endhighlight %}

### More complex workflow

What if our CSV imports grow very large?  Downloading a file and processing many thousands of records is slow.  We can break it up into one job to download the data and then separate jobs to process each row (which will run in parallel).  To keep things simple we will always save the file to the same location.  

{% highlight ruby %}
class DownloadCsvJob < Gush::Job
  def perform
    # save to S3 or other shared location
  end
end
class ImportCsvRowJob < Gush::Job
end
{% endhighlight %}

How do we know when ALL `ImportCsvRowJob` complete so we can run `GenReportJob`?  We change our workflow.  

{% highlight ruby %}
class ImportWorkflow < Gush::Workflow
  def configure
    run ImportXmlJob
    run DownloadCsvJob
    csv_jobs = CSV.foreach("path/to/data.csv").map do |row|
      run ImportCsvRowJob, params: row, after: DownloadCsvJob
    end
    all_jobs = csv_jobs.push(ImportXmlJob)
    run GenReportJob, after: all_jobs    
  end
end
{% endhighlight %}

### Scheduling

Now we want to schedule this workflow for regular execution.  Gush does not provide scheduling functionality so we will create a wrapper job to manage the entire process and kick it off it using something like [sidekiq-cron](https://github.com/ondrejbartas/sidekiq-cron).  This job can contain additional logic to query DB, start other workflows, etc.  It can also be used to cleanup Redis data created by previous workflows.  

{% highlight ruby %}
# config/initializers/gush.rb
GUSH_CLIENT = Gush::Client.new
# app/jobs/
class WorkflowManagerJob < ApplicationJob
  def perform
    import_workflow
    redis_cleanup
    # do other things
  end
private
  def import_workflow
    flow = ImportWorkflow.create
    flow.start!  
  end
  def redis_cleanup
    GUSH_CLIENT.all_workflows.each do |flow|
      if flow.running? == false && flow.finished_at > Time.now - 1.week
        Rails.logger.info "#{flow.id} #{flow.to_hash[:name]} #{flow.finished_at}"
        client.destroy_workflow flow
      end
    end
  end
  ...
end
{% endhighlight %}

### Avoid overlapping workflows

Since we do not know how long our workflow execution will take we might want to avoid starting the next scheduled workflow iteration while the current one with same class is still running.  

{% highlight ruby %}
class WorkflowManagerJob < ApplicationJob
  def perform
    return if find_by_class 'ImportWorkflow'
    ...
  end
private
  def find_by_class klass
    GUSH_CLIENT.all_workflows.each do |flow|
      return true if flow.to_hash[:name] == klass && flow.running?
    end
    return false
  end
end
{% endhighlight %}

### Redis data storage

If the number of jobs in our workflow was static we could have reused the same flow by calling `flow.start!` using the same ID.  But we would need to store that ID somewhere and if Redis data were deleted the ID would be useless.  So it is best to re-create the workflow every time.  Each workflow and job has a separate key in Redis.  Gush serializes everything as JSON and stores it as Redis strings.  

{% highlight ruby %}
{
  "key": "gush.workflows.WORKFLOW_ID",
  "type": "string",
  "value": "{\"name\":\"ImportWorkflow\",\"id\":\"...\",\"arguments\":[],\"klass\":\"ImportWorkflow\",\"jobs\":[...],..}",
}
{
  "key": "gush.jobs.WORKFLOW_ID.GenReportJob-JOB_ID",
  "type": "string",
  "value": "{\"name\":\"GenReportJob-JOB_ID\",\"klass\":\"GenReportJob\",\"incoming\":[\"ImportCsvJob\",\"ImportXmlJob\"],\"workflow_id\":\"WORKFLOW_ID\"...}",
}
{
  "key": "gush.jobs.WORKFLOW_ID.ImportXmlJob-JOB_ID",
  "type": "string",
  "value": "{\"name\":\"ImportXmlJob-JOB_ID\",\"klass\":\"ImportXmlJob\",\"outgoing\":[\"GenReportJob-JOB_ID\"],\"workflow_id\":\"WORKFLOW_ID\",...}",
}
...
{% endhighlight %}

### Alternative queues

The great thing about ActiveJob is that we can easily switch between different queue backends.  We might decide to use AWS SQS with [shoryuken](https://github.com/phstc/shoryuken) or RabbitMQ with [sneakers](https://github.com/jondot/sneakers).  In that case gush will use Redis to only store data on workflow and jobs but NOT use Redis as a queue.  All we need to do is create `gush` queue in SQS, set `config.active_job.queue_adapter = :shoryuken` and provide AWS creds.  Even though SQS does not guarantee order of messages the workflow managed by gush will ensure that `GenReportJob` runs at the very end.  

Since SQS does not support scheduling jobs we would need to use a different mechanism.  Or we could run `WorkflowManagerJob` via Sidekiq with sidekiq-cron by setting `self.queue_adapter = :sidekiq` inside that job class.  Other jobs will run via SQS.  

### Links

[Sidekiq Pro workflow](https://github.com/mperham/sidekiq/wiki/Really-Complex-Workflows-with-Batches)
